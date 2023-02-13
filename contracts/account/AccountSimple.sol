//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "./AccountBase.sol";
import "../utils/GasPayer.sol";

contract AccountSimple is AccountBase, GasPayer {
    using Address for address;

    uint256 private nonce_;

    function init(address owner, bytes memory data) external {
        require(_owner() == address(0) && owner != address(0), "HEXL015");
        _transferOwnership(owner);
        address(this).functionCall(data, "HEXL013");
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function validateAndCall(
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature
    ) public payable {
        bytes32 requestId = keccak256(abi.encode(txData, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success, bytes memory data) = address(this).call(txData);
        Address.verifyCallResult(success, data, "HEXLA009");
    }

    function validateAndCallWithGasRefund(
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature,
        GasPayment calldata gas
    ) external payable {
        uint256 gasUsed = gasleft();
        bytes32 requestId = keccak256(abi.encode(txData, nonce_, gas));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success, bytes memory data) = address(this).call(txData);
        Address.verifyCallResult(success, data, "HEXLA009");
        _refundGas(gas, gasUsed - gasleft());
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}