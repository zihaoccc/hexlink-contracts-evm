//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "./AccountBase.sol";
import "../utils/GasPayer.sol";

contract AccountSimple is AccountBase, GasPayer {
    uint256 private nonce_;

    function init(address owner, bytes memory data) external {
        require(_owner() == address(0) && owner != address(0), "HEXL015");
        _transferOwnership(owner);
        (bool success, ) = address(this).call(data);
        require(success, "HEXL013");
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function validateAndCall(
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature
    ) public {
        bytes32 requestId = keccak256(abi.encode(txData, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success,) = address(this).call(txData);
        require(success, "HEXLA009");
    }

    function validateAndCallWithGasRefund(
        bytes calldata txData,
        uint256 _nonce,
        bytes calldata signature,
        GasPayment calldata gas
    ) external {
        uint256 gasUsed = gasleft();
        validateAndCall(txData, _nonce, signature);
        _refundGas(gas, gasUsed - gasleft());
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}