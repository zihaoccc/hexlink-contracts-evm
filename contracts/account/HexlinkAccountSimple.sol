//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./AccountBase.sol";

contract HexlinkAccountSimple is AccountBase {
    struct AccountStorage {
        bool initialized;
    }

    AccountStorage internal s;

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(address admin, address beacon, bytes memory data) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    function execBatch(BasicUserOp[] calldata ops) external virtual {
        require(msg.sender == _getAdmin(), "HEXL004");
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) external virtual {
        require(msg.sender == _getAdmin(), "HEXL004");
        _exec(op);
    }
}
