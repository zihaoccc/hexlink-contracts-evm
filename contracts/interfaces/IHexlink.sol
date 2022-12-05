// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

struct Request {
    bytes32 name; // user id
    bytes4 func; // function selector
    bytes params; // function params
    uint96 nonce; // nonce to sign
}

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

interface IHexlink {
    function addressOfName(bytes32 name) external view returns (address);

    function deploy(
        Request calldata request,
        AuthProof calldata proof
    ) external;

    function reset(
        Request calldata request,
        AuthProof[] calldata proofs
    ) external;
}