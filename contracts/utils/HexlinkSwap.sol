//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract HexlinkSwapImpl is Ownable, UUPSUpgradeable {
    using ECDSA for bytes32;

    event Deposit(address sender, uint256 amount);
    event Withdraw(address receiver, uint256 amount);
    event Swap(address from, address to, address token, uint256 amount1, uint256 amount2);

    mapping(address => uint256) prices_; // amount token T per ETH
    address validator;
    
    function init(address newOwner, address validator_) external {
        require(owner() == address(0), "already initialized");
        _transferOwnership(newOwner);
        validator = validator_;
    }

    function setValidator(address validator_) external onlyOwner {
        validator = validator_;
    }

    function setPrice(address token, uint256 price) external onlyOwner {
         prices_[token] = price;
    }

    function setPrices(address[] memory tokens, uint256[] memory prices) external onlyOwner {
        require(tokens.length == prices.length, "args length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            prices_[tokens[i]] = prices[i];
        }
    }

    function withdraw(uint256 amount) external onlyOwner {
        address owner = owner();
        emit Withdraw(owner, amount);
        Address.sendValue(payable(owner), amount);
    }

    function getPrice(address token) external view returns(uint256) {
        return prices_[token];
    }

    function deposit() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function swap(address token, uint256 amount, bytes calldata signature) external {
        _validateSiganture(token, amount, signature);
        address owner = owner();
        IERC20(token).transferFrom(msg.sender, owner, amount);
        uint256 price = prices_[token];
        uint256 amount2 = amount * 1000000000000000000 / price;
        Address.sendValue(payable(msg.sender), amount2);
        emit Swap(msg.sender, owner, token, amount, amount2);
    }

    function _validateSiganture(
        address token,
        uint256 amount,
        bytes calldata signature
    ) internal view {
        bytes32 message = keccak256(
            abi.encode(block.chainid, address(this), token, amount)
        );
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(validator == reqHash.recover(signature), "invalid signature");
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view onlyOwner override { }
}

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HexlinkSwapProxy is ERC1967Proxy {
    constructor(
        address logic,
        bytes memory data
    ) ERC1967Proxy(logic, data) payable {}
}