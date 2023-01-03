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
    event Approval(address indexed from, address indexed operator, uint256 allowance);

    ISwapRouter public immutable swapRouter;
    address public immutable wrapped;
    mapping(address => uint256) private balances_;
    // owner => operator => approved
    mapping(address => mapping(address => uint256)) private allowances_;

    constructor(address _swapRouter, address _wrapped) {
        swapRouter = ISwapRouter(_swapRouter);
        wrapped = _wrapped;
    }

    function deposit() external payable {
        balances_[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function depositToken(address token, uint256 amount) external payable {
        // deposit and approve token to uniswap
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        TransferHelper.safeApprove(token, address(swapRouter), amount);
        // swap to weth
        if (token != wrapped) {
            ISwapRouter.ExactInputSingleParams memory param =
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: token,
                    tokenOut: wrapped,
                    fee: 3000, // 0.3%
                    recipient: address(this),
                    deadline: block.timestamp,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });
            amount = swapRouter.exactInputSingle(param);
        }
        // unwrap as eth
        wrapped.functionCall(abi.encodeWithSignature('withdraw(uint256)', amount));
        balances_[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
         balances_[msg.sender] -= amount;
         Address.sendValue(payable(msg.sender), amount);
         emit Withdraw(msg.sender, amount);
    }

    function increaseAllowance(address operator, uint256 amount) external {
        uint256 balance = allowances_[msg.sender][operator];
        allowances_[msg.sender][operator] = balance + amount;
        emit Approval(msg.sender, operator, balance + amount);
    }

    function decreaesAllowance(address operator, uint256 amount) external {
        uint256 balance = allowances_[msg.sender][operator];
        if (balance < amount) {
            amount = balance;
        }
        unchecked { allowances_[msg.sender][operator] = balance - amount; }
        emit Approval(msg.sender, operator, balance - amount);
    }

    function pay(address from, address to, uint amount) external {
        require(from == msg.sender || allowance(msg.sender, from) > amount, "Unauthorized");
        balances_[from] -= amount;
        Address.sendValue(payable(to), amount);
        emit Payment(from, to, amount);
    }

    function depositOf(address user) external view returns(uint256) {
        return balances_[user];
    }

    function allowance(address owner, address operator) public view returns (uint256) {
        return allowances_[owner][operator];
    }
}