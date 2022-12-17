// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HexlinkProxy is ERC1967Proxy {
    constructor(
        address logic,
        bytes memory data
    ) ERC1967Proxy(logic, data) payable {}
}