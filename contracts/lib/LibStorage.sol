// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

import "../structs/AccountStorage.sol";

library LibStorage {
    function accountStorage() internal pure returns (AccountStorage storage ds) {    
        assembly {
            ds.slot := 0
        }
    }
}
