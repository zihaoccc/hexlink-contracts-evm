//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    using Address for address;

    event GasPayment(bytes32 indexed request, uint256 payment);
    uint256 private nonce_;
    
    function init(address owner) external {
        require(_owner() == address(0) && owner != address(0), "HEXL015");
        _transferOwnership(owner);
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function depositGas(
        address gasStation,
        uint256 amount
    ) external returns(uint256) {
        _validateCaller();
        uint256 payment = amount * tx.gasprice;
        gasStation.functionCallWithValue(
            abi.encodeWithSignature("deposit()"),
            payment
        );
        return payment;
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