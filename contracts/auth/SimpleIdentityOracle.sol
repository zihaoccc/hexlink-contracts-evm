// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@solidstate/contracts/access/ownable/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../utils/Initializable.sol";

contract SimpleIdentityOracle is IERC1271, Ownable, Initializable {
    using ECDSA for bytes32;

    event Register(
        address indexed validator,
        bool registered
    );

    event RegisterBatch(
        address[] indexed validators,
        bool[] registered
    );

    event Clone(address indexed cloned);

    mapping(address => bool) validators_;

    constructor(address owner) {
        init(owner);
    }

    function clone(bytes32 salt, address owner) external {
        address oracle = Clones.cloneDeterministic(address(this), salt);
        SimpleIdentityOracle(oracle).init(owner);
        emit Clone(oracle);
    }

    function init(address owner) public initializer {
        OwnableStorage.layout().owner = owner;
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
        for (uint i = 0; i < validators.length; i++) {
            _register(validators[i], registered[i]);
        }
        emit RegisterBatch(validators, registered);
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
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );
        require(validator == messageHash.recover(sig), "IO003");
        return IERC1271.isValidSignature.selector;
    }
}