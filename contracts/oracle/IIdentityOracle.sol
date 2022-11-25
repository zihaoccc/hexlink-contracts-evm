// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface IIdentityOracle {
    function validate(
        bytes32 /* nameHash */,
        bytes memory /* authProof */
    ) external view returns (bool);
}