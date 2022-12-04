// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

struct Request {
    bytes32 name; // user id
    bytes4 func; // function selector
    bytes params; // function params
    uint256 nonce; // nonce to sign
}

/*
 * The request id is a hash over the request, contract processing
 * the request and chainId. The signature is signed over keccak256
 * hash of AuthProofToSign struct
 */
struct AuthProof{
    bytes32 name;
    bytes32 requestId;
    uint256 expiredAt; // set by oracle verifiers
    uint256 authType; // set by oracle verifiers
    bytes signature; // aggregated signature
}

interface IHexlink {
    function accountImpl() external view returns (address);

    function addressOfName(bytes32 name) external view returns (address);

    function deploy(
        Request calldata request,
        AuthProof calldata proof
    ) external;

    function reset(
        Request calldata request,
        AuthProof calldata proof
    ) external;

    function reset2Fac(
        Request calldata request,
        AuthProof calldata proof1,
        AuthProof calldata proof2
    ) external;

    function reset2Stage(
        Request calldata request,
        AuthProof calldata proof
    ) external;
}