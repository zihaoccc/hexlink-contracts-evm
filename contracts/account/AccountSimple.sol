//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    function _init(bytes calldata initData) internal override {
        (address admin, address beacon, bytes memory data) =
            abi.decode(initData, (address, address, bytes));
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
