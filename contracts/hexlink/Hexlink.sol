// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./HexlinkImpl.sol";

contract HexlinkUpgradeable is HexlinkImpl, UUPSUpgradeable {
    constructor(address accountBase) HexlinkImpl(accountBase) { }

    function init(
        address owner,
        address oracleRegistry
    ) public {
        require(_owner() == address(0), "HEXL015");
        _transferOwnership(owner);
        _setOracleRegistry(oracleRegistry);
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view onlyOwner override { }
}

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract Hexlink is ERC1967Proxy {
    constructor(
        address logic,
        bytes memory data
    ) ERC1967Proxy(logic, data) payable {}
}
