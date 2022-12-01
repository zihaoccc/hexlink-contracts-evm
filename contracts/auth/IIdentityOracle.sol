// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface IIdentityOracle {
    function validate(
        bytes32 message,
        address[] memory verifiers,
        bytes memory signature
    ) external view returns (bool);
}