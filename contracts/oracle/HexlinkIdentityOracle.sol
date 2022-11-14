// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IIdentityOracle.sol";

contract HexlinkIdentityOracle is IIdentityOracle, Ownable {
    mapping(uint32 => address) validators_;

    constructor() Ownable() { }

    function setValidator(uint32 identityType, address validator, bytes memory signature) external onlyOwner {
        require(validator != address(0), "HEXL005");
        validators_[identityType] = validator;
    }

    function validate(
        bytes32 /* nameHash */,
        AuthProof memory authProof
    ) external view override returns (bool) {
        address validator = validators_[authProof.identityType];
        require(validator != address(0), "HEXL004");
        return false;
    }
}