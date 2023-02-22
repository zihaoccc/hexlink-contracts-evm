//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "./AccountBase.sol";
import "../utils/GasPayer.sol";
import "../utils/ISwap.sol";

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
        _validateAndRun(requestId, txData, _nonce, signature);
    }

    function validateAndCallWithGasRefund(
        bytes calldata txData,
        uint256 _nonce,
        GasPayment calldata gas,
        bytes calldata signature
    ) external payable {
        uint256 gasUsed = gasleft();
        bytes32 requestId = keccak256(abi.encode(txData, nonce_, gas));
        _validateAndRun(requestId, txData, _nonce, signature);
        _refundGas(gas, gasUsed - gasleft());
    }

    function _validateAndRun(
        bytes32 requestId,
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature
    ) internal {
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success, bytes memory data) = address(this).call(txData);
        Address.verifyCallResult(success, data, "HEXLA009");
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}