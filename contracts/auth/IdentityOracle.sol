// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

contract IdentityOracle is IERC1271, SafeOwnable {
    mapping(uint32 => address) validators_;

    constructor() Ownable() { }

    function registerVerifier(
        uint32 identityType,
        address validator,
        bytes memory /* signature */
    ) external onlyOwner {
        require(validator != address(0), "HEXL005");
        validators_[identityType] = validator;
    }

    function isValidSignature(
        bytes32 /* message */,
        bytes memory /* signature */
    ) external pure override returns(bytes4) {
        revert("Not Implemented");
    }
}