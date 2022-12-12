// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../utils/Initializable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradable is Hexlink, Initializable, UUPSUpgradeable {
    constructor(address accountBase) Hexlink(accountBase) { }

    function init(
        address owner,
        address oracleRegistry
    ) public initializer {
        OwnableStorage.layout().owner = owner;
        _setOracleRegistry(oracleRegistry);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner override { }
}
