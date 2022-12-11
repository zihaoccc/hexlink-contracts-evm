// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../auth/AuthProof.sol";

interface IHexlink {
    function accountBase() external view returns (address);

    function addressOfName(bytes32 name) external view returns (address);

    function bumpNonce(
        bytes32 name,
        AuthProof calldata proof
    ) external;

    function deploy(
        bytes32 name,
        bytes calldata txData,
        AuthProof calldata proof
    ) external;

    function reset(
        bytes32 name,
        address account,
        AuthProof calldata proof
    ) external;

    function reset2Fac(
        bytes32 name,
        address account,
        AuthProof calldata proof1,
        AuthProof calldata proof2
    ) external;

    function reset2Stage(
        bytes32 name,
        address account,
        AuthProof calldata proof
    ) external;
}