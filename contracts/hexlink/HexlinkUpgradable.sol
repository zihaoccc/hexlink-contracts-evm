// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./Hexlink.sol";

contract HexlinkUpgradable is Hexlink, UUPSUpgradeable {
    constructor(address accountImpl, address owner) Hexlink(accountImpl, owner) { }

    function _authorizeUpgrade(
        address newImplementation
    ) internal onlyOwner override { }
}
