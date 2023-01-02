// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract SimpleIdentityOracle is IERC1271, Ownable {
    using ECDSA for bytes32;

    event Register(
        address indexed validator,
        bool registered
    );

    event RegisterBatch(
        address[] indexed validators,
        bool[] registered
    );

    event Cloned(address indexed cloned);

    mapping(address => bool) validators_;

    function clone(bytes32 salt) external {
        address oracle = Clones.cloneDeterministic(address(this), salt);
        emit Cloned(oracle);
    }

    function init(
        address owner,
        address[] memory validators,
        bool[] memory registered
    ) external {
        require(_owner() == address(0), "HEXL015");
        _transferOwnership(owner);
        _registerBatch(validators, registered);
    }

    function isRegistered(address validator) external view returns (bool) {
        return validators_[validator];
    }

    function register(
        address validator,
        bool registered
    ) external onlyOwner {
        _register(validator, registered);
        emit Register(validator, registered);
    }

    function registerBatch(
        address[] memory validators,
        bool[] memory registered
    ) public onlyOwner {
        _registerBatch(validators, registered);
        emit RegisterBatch(validators, registered);
    }

    function _registerBatch(
        address[] memory validators,
        bool[] memory registered
    ) internal {
        for (uint i = 0; i < validators.length; i++) {
            _register(validators[i], registered[i]);
        }
    }

    function _register(
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
        bytes32 messageHash = message.toEthSignedMessageHash();
        require(validator == messageHash.recover(sig), "IO003");
        return IERC1271.isValidSignature.selector;
    }
}