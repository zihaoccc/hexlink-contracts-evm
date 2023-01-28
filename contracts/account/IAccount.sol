// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "../utils/Op.sol";

interface IAccount {
    function execBatch(Op[] calldata ops) external payable;

    function exec(Op calldata op) external payable;
}
