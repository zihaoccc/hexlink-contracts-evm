// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradable is Hexlink, UUPSUpgradeable {
    constructor(address _oracle) Hexlink(_oracle) { }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner override { }
}
