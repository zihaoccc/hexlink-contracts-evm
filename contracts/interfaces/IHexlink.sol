// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../utils/Auth.sol";

struct Request {
    bytes32 name; // user id
    bytes4 func; // function selector
    bytes params; // function params
    uint96 nonce; // nonce to sign
}

interface IHexlink {
    function accountBase() external view returns (address);

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