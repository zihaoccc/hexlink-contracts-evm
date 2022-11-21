// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

struct AccountStorage {
    address entryPoint;
    uint64 nonce;
    bool initialized;
}

library LibAccountStorage {
    function accountStorage() internal pure returns (AccountStorage storage ds) {    
        assembly {
            ds.slot := 0
        }
    }
}
