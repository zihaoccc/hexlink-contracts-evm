// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

/*
 * The request id is a hash over the HexlinkRequest(except verifiers and
 * signature) and chainId. The signature is signed over request id
 */
struct HexlinkRequest {
    bytes32 nameHash; // user id
    bytes4 functionToCall; // function selector
    bytes functionParams; // function params
    uint256 nonce; // nonce to sign
    uint256 authType; // set by oracle verifiers
    uint64 verifiedAt; // set by oracle verifiers
    address[] verifiers; // set by oracle verifiers, optional
    bytes signature; // signed by oracle verifiers
}

struct RequestToSign {
    bytes32 nameHash; // user id
    bytes4 functionToCall; // function selector
    bytes32 functionParamsHash; // function params
    uint256 nonce; // nonce to sign
    uint256 authType; // set by oracle verifiers
    uint64 verifiedAt; // set by oracle verifiers
    address oracle;
    uint256 chainId;
}

struct AuthState {
    bytes32 lastParamsHash;
    uint64 lastVerifiedAt;
    uint16 totalAuthAttempts;
    uint16 totalAuthMethods;
}
