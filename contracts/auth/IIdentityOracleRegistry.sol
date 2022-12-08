// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface IIdentityOracleRegistry {
    function oracle(
        uint128 identityType,
        uint128 authType
    ) external view returns(address);
}