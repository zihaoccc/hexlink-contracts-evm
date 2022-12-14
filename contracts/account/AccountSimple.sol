//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "./AccountBase.sol";
import "../utils/Initializable.sol";

contract AccountSimple is AccountBase, Initializable {
    using Address for address;
    
    event GasPayment(bytes32 indexed request, uint256 gasCost);

    struct AppStorage {
        uint256 nonce;
    }
    AppStorage internal s;
    
    function init(address owner) external initializer {
        OwnableStorage.layout().owner = owner;
    }

    function validateAndCall(
        bytes calldata txData,
        address refundReceiver,
        uint256 reward, // reward to gas payer
        uint256 nonce,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        require(msg.sender != address(this), "HEXLA007");
        require(s.nonce++ == nonce, "HEXLA008");
        bytes32 request = keccak256(abi.encode(txData, refundReceiver, reward, nonce));
        _validateSignature(request, signature);
        address(this).functionCall(txData, "HEXLA009");
        // payment = 21000 gas
        // emit = 1200 gas = 375(log) + 375(topic) + 32 * 8(logData) + 64 * 3(memory)
        // buffer = 700 gas
        gasUsed = (gasUsed + 23000 + reward - gasleft()) * tx.gasprice;
        refundReceiver.functionCallWithValue("", gasUsed, "HEXLA010");
        emit GasPayment(request, gasUsed);
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }
}