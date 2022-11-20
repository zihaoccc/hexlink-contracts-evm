
// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

struct BasicUserOp {
    address to;
    uint256 value;
    bytes callData;
    uint256 callGasLimit; // gas used for tx execution
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
}

struct UserOp {
    address user;
    uint256 value;
    bytes callData;
    uint256 nonce;
    uint256 callGasLimit; // gas used for tx execution
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    uint256 baseGasLimit; // gas used for verification and refund
    uint256 gasRelayerBonus; // reward for gas relayer
    address payable refundReceiver;
    bytes signature;
}