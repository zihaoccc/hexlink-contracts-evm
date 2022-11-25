//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./AccountBase.sol";

contract HexlinkAccountSimple is AccountBase {
    struct AccountStorage {
        bool initialized;
    }

    AccountStorage internal s;

    modifier onlyAdmin() {
        require(msg.sender == _getAdmin(), "HEXL013");
        _;
    }

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(address admin, address beacon, bytes memory data) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    function changeAdmin(address newAdmin) onlyAdmin external {
        _changeAdmin(newAdmin);
    }

    function upgradeBeaconToAndCall(
        address beacon,
        bytes memory data,
        bool forceCall
    ) onlyAdmin external {
        _upgradeBeaconToAndCall(beacon, data, forceCall);
    }

    function execBatch(BasicUserOp[] calldata ops) onlyAdmin external virtual {
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) onlyAdmin external virtual {
        _exec(op);
    }
}
