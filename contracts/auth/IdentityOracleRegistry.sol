// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IIdentityOracleRegistry.sol";
import "hardhat/console.sol";

contract IdentityOracleRegistry is IIdentityOracleRegistry, Ownable {
    using Address for address;

    event Register(
        OracleSelector selector,
        address oracle
    );

    event RegisterBatch(
        OracleSelector[] selectors,
        address[] oracles
    );

    mapping(bytes32 => address) private oracles_;

    constructor(address owner) {
        _transferOwnership(owner);
    }

    function oracle(
        OracleSelector calldata selector
    ) public view override returns (address) {
        return oracles_[_lookUpKey(selector)];
    }

    function register(
        OracleSelector calldata selector,
        address _oracle
    ) external onlyOwner {
        _register(selector, _oracle);
        emit Register(selector, _oracle);
    }

    function registerBatch(
        OracleSelector[] calldata selectors,
        address[] memory oracles
    ) public onlyOwner {
        require(selectors.length == oracles.length, "HEXL001");
        for (uint256 i = 0; i < oracles.length; i++) {
            _register(selectors[i], oracles[i]);
        }
        emit RegisterBatch(selectors, oracles);
    }

    function _register(
        OracleSelector calldata selector,
        address _oracle
    ) internal {
        require(selector.identityType != 0 && _oracle != address(0), "HEXL002");
        require(_oracle.isContract(), "HEXL013");
        oracles_[_lookUpKey(selector)] = _oracle;
    }

    function _lookUpKey(
        OracleSelector calldata selector
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(selector));
    }
}