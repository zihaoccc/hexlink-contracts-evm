// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface IIdentityOracle {
    /* This function will
       1. revert if validation fails
       2. return true if it passes validation
       3. return false if it passes validation but waiting for other state change
    */
    function validate(
        bytes32 nameHash,
        bytes memory authProof,
        uint8 policy
    ) external view returns (bool);
}