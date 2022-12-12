// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

struct OracleSelector {
    uint256 identityType;
    uint256 authType;
}

interface IIdentityOracleRegistry {
    function oracle(
        OracleSelector calldata selector
    ) external view returns(address);
}