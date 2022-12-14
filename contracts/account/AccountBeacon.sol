//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract AccountBeacon is UpgradeableBeacon {
    constructor(address impl, address owner) UpgradeableBeacon(impl) {
        _transferOwnership(owner);
    }
}