//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./AccountBase.sol";

contract AccountERC4337 is AccountBase, BaseWallet {
    struct AppStorage {
        address entryPoint;
        uint64 nonce;
    }

    event SetEntryPoint(address indexed newEntryPoint);

    AppStorage internal s;

    function _init(bytes calldata initData) internal override {
        (address admin, address beacon, bytes memory data, address _entryPoint) =
            abi.decode(initData, (address, address, bytes, address));
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
        _updateEntryPoint(_entryPoint);
    }

    function nonce() public view virtual returns (uint256) {
        return s.nonce;
    }

    function entryPoint() public view override virtual returns (address) {
        return s.entryPoint;
    }

    function execBatch(BasicUserOp[] calldata ops) onlyEntryPoint external virtual {
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) onlyEntryPoint external virtual {
        _exec(op);
    }

    function changeAdmin(address newAdmin) onlyEntryPoint external {
        _changeAdmin(newAdmin);
    }

    function upgradeBeaconToAndCall(
        address beacon,
        bytes memory data,
        bool forceCall
    ) onlyEntryPoint external {
        _upgradeBeaconToAndCall(beacon, data, forceCall);
    }

    function updateEntryPoint(address newEntryPoint) onlyEntryPoint external {
        _updateEntryPoint(newEntryPoint);
    }

    function _updateEntryPoint(address newEntryPoint) internal {
        s.entryPoint = newEntryPoint;
        emit SetEntryPoint(newEntryPoint);
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override virtual {
        require(s.nonce++ == userOp.nonce, "HEXLA005");
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 requestId, address)
    internal override returns (uint256) {
        _validateSignature(requestId, userOp.signature);
        return 0;
    }
}
