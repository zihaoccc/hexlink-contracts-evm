// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface INonce {
    function nonce(bytes32 name) external view returns(uint96);
}