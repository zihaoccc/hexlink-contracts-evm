//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/governance/TimelockController.sol";

// set this as the admin of hexlink contracts
contract HexlinkAdmin is TimelockController {
    // the proposers and exectutors should be the gnosis safe
    // contract to support multi-sig
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors
    ) TimelockController(minDelay, proposers, executors, address(0)) { }
}