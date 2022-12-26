//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./AccountBase.sol";

contract AccountERC4337 is AccountBase, BaseWallet {
    event SetEntryPoint(address indexed newEntryPoint);

    struct AppStorage {
        uint256 nonce;
        address entryPoint;
    }
    AppStorage internal s;

    function init(address owner, address _entryPoint) external {
        require(_owner() == address(0), "HEXL015");
        _transferOwnership(owner);
        s.entryPoint = _entryPoint;
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

    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override virtual {
        require(s.nonce++ == userOp.nonce, "HEXLA005");
    }

    function _validateSignature(
        UserOperation calldata userOp, 
        bytes32 requestId, address
    ) internal view override returns (uint256) {
        _validateSignature(requestId, userOp.signature);
        return 0;
    }

    function _validateCaller() internal view override {
        require(msg.sender == s.entryPoint
            || msg.sender == owner(), "HEXLA013");
    }
}
