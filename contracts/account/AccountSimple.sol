//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    function _init(bytes calldata initData) internal override {
        (address admin, address beacon) =
            abi.decode(initData, (address, address));
        _init(admin, beacon);
    }

    function changeAdmin(address newAdmin) external {
        _validateCaller();
        _changeAdmin(newAdmin);
    }

    function upgradeBeaconToAndCall(
        address beacon,
        bytes memory data,
        bool forceCall
    ) external {
        _validateCaller();
        _upgradeBeaconToAndCall(beacon, data, forceCall);
    }

    function execBatch(BasicUserOp[] calldata ops) external virtual {
        _validateCaller();
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) external virtual {
        _validateCaller();
        _exec(op);
    }

    function _validateCaller() internal virtual {
        require(msg.sender == _getAdmin(), "HEXLA012");
    }
}
