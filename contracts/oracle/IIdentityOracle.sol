// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

interface IIdentityOracle {
    struct AuthProof {
        address verifier;
        uint64 issuedAt;
        uint64 expiredAt;
        uint32 identityType;
        bytes signature;
    }

    function validate(
        bytes32 /* nameHash */,
        AuthProof calldata /* authProof */
    ) external view returns (bool);
}