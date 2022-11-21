//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

struct BasicUserOp {
    address to;
    uint256 value;
    bytes callData;
    uint256 callGasLimit; // gas used for tx execution
}