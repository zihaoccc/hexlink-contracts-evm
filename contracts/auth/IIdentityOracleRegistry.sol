// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

struct OracleSelector {
    bytes32 identityType;
    bytes32 authType;
}

interface IIdentityOracleRegistry {
    function oracle(
        OracleSelector calldata selector
    ) external view returns(address);
}