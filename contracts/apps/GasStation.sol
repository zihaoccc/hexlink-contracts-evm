//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

contract GasStation {
    using Address for address;

    event Deposit(address indexed from, uint256 amount);
    event Payment(address indexed from, address indexed to, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event Approval(address indexed from, address indexed operator, bool approval);

    ISwapRouter public immutable swapRouter;
    address public immutable WETH;
    mapping(address => uint256) private deposits_;
    // owner => operator => approved
    mapping(address => mapping(address => bool)) private approval_;

    constructor(ISwapRouter _swapRouter, address _WETH) {
        swapRouter = _swapRouter;
        WETH = _WETH;
    }

    function depositNativeCoin() external payable {
        deposits_[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function depositToken(address token, uint256 amount) external payable {
        // deposit eth
        deposits_[msg.sender] += msg.value;
        // deposit and approve token to uniswap
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        TransferHelper.safeApprove(token, address(swapRouter), amount);
        if (token != WETH) {
            // swap to weth
            ISwapRouter.ExactInputSingleParams memory param =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token,
                    tokenOut: WETH,
                    fee: 3000, // 0.3%
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            amount = swapRouter.exactInputSingle(param);
        }
        // withdraw as eth
        WETH.functionCall(abi.encodeWithSignature('withdraw(uint256)', amount));
        deposits_[msg.sender] += amount;
        emit Deposit(msg.sender, msg.value + amount);
    }

    function withdraw(uint256 amount) external {
         deposits_[msg.sender] -= amount;
         Address.sendValue(payable(msg.sender), amount);
         emit Withdraw(msg.sender, amount);
    }

    function approve(address operator, bool approval) external {
        approval_[msg.sender][operator] = approval;
        emit Approval(msg.sender, operator, approval);
    }

    function pay(address from, address to, uint amount) external {
        require(from == msg.sender || approved(msg.sender, from), "Unauthorized");
        require(deposits_[from] >= amount, "Insufficient balance");
        unchecked { deposits_[from] -= amount; }
        Address.sendValue(payable(to), amount);
        emit Payment(from, to, amount);
    }

    function depositOf(address user) external view returns(uint256) {
        return deposits_[user];
    }

    function approved(address owner, address operator) public view returns (bool) {
        return approval_[owner][operator];
    }
}