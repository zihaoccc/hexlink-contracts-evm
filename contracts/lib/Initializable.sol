
//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "./IInitializable.sol";

library InitializerStorage {
    struct Layout {
        bool initialized;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('hexlink.contracts.storage.InitializableStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract Initializable is IInitializable {
    modifier initializer() {
        InitializerStorage.Layout storage s = InitializerStorage.layout();
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(bytes memory initData) external initializer {
        _init(initData);
    }

    function _init(bytes memory initData) internal virtual;
}