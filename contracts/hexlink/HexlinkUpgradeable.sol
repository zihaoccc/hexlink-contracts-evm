// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradeable is Hexlink, UUPSUpgradeable {
    constructor(address accountBase) Hexlink(accountBase) { }

    function init(
        address owner,
        address oracleRegistry
    ) public {
        require(_owner() == address(0), "HEXL015");
        _transferOwnership(owner);
        _setOracleRegistry(oracleRegistry);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner override { }
}
