// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";

contract HexlinkBeaconProxy is Proxy, ERC1967Upgrade {
    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal override view returns (address) {
        return IBeacon(_getBeacon()).implementation();
    }
}