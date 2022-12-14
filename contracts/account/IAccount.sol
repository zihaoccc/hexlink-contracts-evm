// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

struct BasicUserOp {
    address to;
    uint256 value;
    bytes callData;
    uint256 callGasLimit;
}

interface IAccount {
    function execBatch(BasicUserOp[] calldata ops) external;

    function exec(BasicUserOp calldata op) external;
}