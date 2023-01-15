// SPDX-License-Identifier: MIT
// HappyRedPacket Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract HappyRedPacketProxy is ERC1967Proxy {
    constructor(
        address logic,
        bytes memory data
    ) ERC1967Proxy(logic, data) payable {}
}