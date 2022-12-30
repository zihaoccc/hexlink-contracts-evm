//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "./AccountBase.sol";
import "../utils/GasPayer.sol";

contract AccountSimple is AccountBase, GasPayer {
    using Address for address;

    struct GasObject {
        address token;
        uint256 price;
        uint256 core;
        uint256 base;
        address payable refundReceiver;
    }

    event GasPayment(bytes32 indexed request, uint256 payment);
    uint256 private nonce_;
    
    function init(address owner) external {
        require(_owner() == address(0), "HEXL015");
        require(owner != address(0), "HEXL019");
        _transferOwnership(owner);
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function validateAndCall(
        bytes calldata txData,
        GasObject calldata gas, // gas settings
        uint256 _nonce,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        bytes32 requestId = keccak256(abi.encode(txData, gas, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        uint256 gaslimit = gas.core == 0 ? gasleft() : gas.core;
        (bool success,) = address(this).call{gas: gaslimit}(txData);
        require(success, "HEXLA009");
        uint256 payment = _handleGasPayment(
            gasUsed - gasleft() + gas.base,
            gas.token,
            gas.price,
            gas.refundReceiver
        );
        emit GasPayment(requestId, payment);
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}