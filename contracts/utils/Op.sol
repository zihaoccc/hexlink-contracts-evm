//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

struct Op {
    address to;
    uint256 value;
    bytes callData;
    uint256 callGasLimit;
}