// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract AccountProxy is Proxy {
    address immutable public beacon;

    constructor(address _beacon) {
        beacon = _beacon;
    }

    /**
     * @dev Returns the current implementation address of the associated beacon.
     */
    function _implementation() internal override view returns (address) {
        return IBeacon(beacon).implementation();
    }
}