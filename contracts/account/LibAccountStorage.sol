// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

struct AccountStorage {
    bool initialized;
    address entryPoint;
    uint64 nonce;
}

library LibAccountStorage {
    function accountStorage() internal pure returns (AccountStorage storage ds) {    
        assembly {
            ds.slot := 0
        }
    }
}
