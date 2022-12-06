//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./AccountBase.sol";

contract AccountERC4337 is AccountSimple, BaseWallet {
    event SetEntryPoint(address indexed newEntryPoint);

    struct AppStorage {
        address entryPoint;
        uint256 nonce;
    }
    AppStorage internal s;

    function _init(bytes calldata initData) internal override {
        (address admin, address beacon, bytes memory data, address _entryPoint) =
            abi.decode(initData, (address, address, bytes, address));
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
        s.entryPoint = newEntryPoint;
    }

    function nonce() public view virtual returns (uint256) {
        return s.nonce;
    }

    function entryPoint() public view override virtual returns (address) {
        return s.entryPoint;
    }

    function updateEntryPoint(address newEntryPoint) onlyEntryPoint external {
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

    function _validateCaller() internal override {
        require(msg.sender == entrypoint() || msg.sender == _getAdmin(), "HEXLA013");
    }
}
