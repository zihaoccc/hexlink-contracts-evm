// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "../utils/Initializable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradable is Hexlink, Initializable, UUPSUpgradeable {
    constructor(address accountImpl) Hexlink(accountImpl) { }

    function _init(bytes calldata data) internal override {
        (
            address owner,
            uint256[] memory authTypes,
            address[] memory oracles
        ) = abi.decode(data, (address, uint256[], address[]));
        OwnableStorage.layout().owner = owner;
        _setOracles(authTypes, oracles);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner override { }
}
