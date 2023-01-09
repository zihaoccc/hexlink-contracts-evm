//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    using Address for address;

    uint256 private nonce_;

    function init(address owner) external {
        require(_owner() == address(0) && owner != address(0), "HEXL015");
        _transferOwnership(owner);
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function refundGas(
        address payable receiver,
        address token,
        uint256 amount,
        uint256 price
    ) external returns (uint256 payment) {
        _validateCaller();
        if (token == address(0)) {
            // price cannot be higher than tx.gasprice
            if (price == 0) {
                price = tx.gasprice;
            } else {
                price = price < tx.gasprice ? price : tx.gasprice;
            }
            payment = amount * tx.gasprice;
            Address.sendValue(receiver, payment);
        } else {
            payment = amount * price;
            IERC20(token).transfer(receiver, payment);
        }
    }

    function validateAndCall(
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature
    ) external {
        bytes32 requestId = keccak256(abi.encode(txData, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success,) = address(this).call(txData);
        require(success, "HEXLA009");
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}