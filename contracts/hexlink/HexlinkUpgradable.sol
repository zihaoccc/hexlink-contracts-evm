// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradable is Hexlink, UUPSUpgradeable, Ownable {
    constructor(address _oracle, address _beacon) Hexlink(_oracle, _beacon) { }

    function _authorizeUpgrade(address newImplementation) internal onlyOwner override { }
}
