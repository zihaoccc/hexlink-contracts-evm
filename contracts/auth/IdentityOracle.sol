// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract IdentityOracle is IERC1271, SafeOwnable {
    using ECDSA for bytes32;

    struct State {
        bool registered;
    }

    mapping(address => State) validators_;

    constructor() Ownable() { }

    function registerVerifier(
        address validator,
        bytes memory /* signature */
    ) external onlyOwner {
        require(validator != address(0), "IO001");
        validators_[validator].registered = true;
    }

    function isValidSignature(
        bytes32 message,
        bytes memory signature
    ) external view override returns(bytes4) {
        (address validator, bytes memory sig) = abi.decode(signature, (address, bytes));
        require(validators_[validator].registered, "IO002");
        require(validator == message.recover(sig), "IO003");
        return IERC1271.isValidSignature.selector;
    }
}