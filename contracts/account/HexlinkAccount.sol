//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./LibAccountStorage.sol";
import "./HexlinkAccountBase.sol";

contract HexlinkAccount is HexlinkAccountBase, BaseWallet {
    using LibUserOperation for UserOperation;

    event SetEntryPoint(address indexed newEntryPoint);

    AccountStorage internal s;

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    modifier onlyEntryPoint() {
        require(msg.sender == s.entryPoint, "HEXL002");
        _;
    }

    function init(address admin, address beacon, bytes memory data, address ep) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
        _updateEntryPoint(ep);
    }

    function nonce() public view virtual returns (uint256) {
        return s.nonce;
    }

    function entryPoint() public view virtual returns (address) {
        return s.entryPoint;
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override virtual {
        require(s.nonce++ == userOp.nonce, "HEXL008");
    }

    function updateEntryPoint(address newEntryPoint) public onlyEntryPoint virtual {
        _updateEntryPoint(newEntryPoint);
    }

    function _updateEntryPoint(address newEntryPoint) internal virtual {
        s.entryPoint = newEntryPoint;
        emit SetEntryPoint(newEntryPoint);
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 requestId, address)
    internal override virtual returns (uint256 deadline) {
        userOp.validateSig(requestId, _getAdmin());
        return 0;
    }

    function _requireFromAdmin() internal override view {
        require(msg.sender == address(this) || msg.sender == _getAdmin() || msg.sender == entryPoint(), "HEXL011");
    }

    function execBatchFromEntryPoint(BasicUserOp[] calldata ops) external onlyEntryPoint {
        _execBatch(ops);
    }

    function execFromEntryPoint(BasicUserOp calldata op) external onlyEntryPoint {
        _exec(op);
    }
}
