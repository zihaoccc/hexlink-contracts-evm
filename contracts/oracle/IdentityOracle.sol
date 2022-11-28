// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "./IIdentityOracle.sol";

contract IdentityOracle is IIdentityOracle, SafeOwnable {
    mapping(uint32 => address) validators_;

    constructor() Ownable() { }

    function setValidator(
        uint32 identityType,
        address validator,
        bytes memory /* signature */
    ) external onlyOwner {
        require(validator != address(0), "HEXL005");
        validators_[identityType] = validator;
    }

    function validate(
        bytes32 /* nameHash */,
        bytes memory /* authProof */,
        uint8 /* policy */
    ) external pure override returns (bool) {
        return false;
    }
}