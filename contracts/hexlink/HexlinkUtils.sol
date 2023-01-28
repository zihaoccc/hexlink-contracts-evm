// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";

abstract contract HexlinkUtils {
    using Address for address;

    function process(
        address[] calldata to,
        uint256[] calldata value,
        bytes[] calldata data
    ) external payable {
        require(
            to.length == data.length && to.length == value.length,
            "Invalid params"
        );
        for (uint256 i = 0; i < to.length; i++) {
            if (value[i] > 0) {
                Address.sendValue(payable(to[i]), value[i]);
            }
            if (data[i].length > 0) {
                to[i].functionCall(data[i]);
            }
        }
    }
}