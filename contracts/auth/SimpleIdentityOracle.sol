// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SimpleIdentityOracle is IERC1271, Ownable2Step {
    using ECDSA for bytes32;

    event SetValidator(
        address indexed validator,
        bool registered
    );

    event SetValidators(
        address[] indexed validators,
        bool[] registered
    );

    mapping(address => bool) validators_;

    constructor(address owner) {
        _transferOwnership(owner);
    }

    function isRegistered(address validator) external view returns (bool) {
        return validators_[validator];
    }

    function setValidator(
        address validator,
        bool registered
    ) external onlyOwner {
        _setValidator(validator, registered);
        emit SetValidator(validator, registered);
    }

    function setValidators(
        address[] memory validators,
        bool[] memory registered
    ) public onlyOwner {
        for (uint i = 0; i < validators.length; i++) {
            _setValidator(validators[i], registered[i]);
        }
        emit SetValidators(validators, registered);
    }

    function _setValidator(
        address validator,
        bool registered
    ) internal {
        require(validator != address(0), "IO001");
        validators_[validator] = registered;
    }

    function isValidSignature(
        bytes32 message,
        bytes memory signature
    ) external view override returns(bytes4) {
        (
            address validator,
            bytes memory sig
        ) = abi.decode(signature, (address, bytes));
        require(validators_[validator], "IO002");
        require(validator == message.recover(sig), "IO003");
        return IERC1271.isValidSignature.selector;
    }
}