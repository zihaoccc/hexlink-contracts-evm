//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

/*
 * The request id is a hash over the request, contract processing
 * the request and chainId. The signature is signed over keccak256
 * hash of AuthProofToSign struct
 */
struct AuthProof{
    uint256 issuedAt; // set by oracle verifiers
    uint256 authType; // set by oracle verifiers
    bytes signature; // aggregated signature
}
