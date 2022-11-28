// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

library OracleConsumerStorage {
    struct Layout {
        address oracle;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('hexlink.contracts.storage.OracleConsumerStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract OracleConsumer {
    constructor(address _oracle) {
        OracleConsumerStorage.layout().oracle = _oracle;
    }

    function oracle() public view returns (address) {
        return OracleConsumerStorage.layout().oracle;
    }

    function _updateOracle(address newOracle) internal {
        OracleConsumerStorage.layout().oracle = newOracle;
    }
}
