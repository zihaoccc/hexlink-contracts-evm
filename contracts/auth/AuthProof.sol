//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

/*
 * The request id is a hash over the request, contract processing
 * the request and chainId. The signature is signed over keccak256
 * hash of AuthProofToSign struct
 */
struct AuthProof{
    uint256 issuedAt;
    uint256 authType;
    uint256 identityType;
    bytes signature; // aggregated signature
}