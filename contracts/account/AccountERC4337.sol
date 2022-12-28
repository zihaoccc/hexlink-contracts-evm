//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./AccountBase.sol";

contract AccountERC4337 is AccountBase, BaseWallet {
    event SetEntryPoint(address indexed newEntryPoint);

    uint256 internal nonce_;
    address internal entryPoint_;

    function init(address owner, address _entryPoint) external {
        require(_owner() == address(0), "HEXL015");
        _transferOwnership(owner);
        entryPoint_ = _entryPoint;
    }

    function nonce() public view virtual returns (uint256) {
        return nonce_;
    }

    function entryPoint() public view override virtual returns (address) {
        return entryPoint_;
    }

    function updateEntryPoint(address newEntryPoint) onlyEntryPoint external {
        entryPoint_ = newEntryPoint;
        emit SetEntryPoint(newEntryPoint);
    }

    function _validateAndUpdateNonce(
        UserOperation calldata userOp
    ) internal override virtual {
        require(nonce_++ == userOp.nonce, "HEXLA005");
    }

    function _validateSignature(
        UserOperation calldata userOp, 
        bytes32 requestId, address
    ) internal view override returns (uint256) {
        _validateSignature(requestId, userOp.signature);
        return 0;
    }

    function _validateCaller() internal view override {
        require(msg.sender == entryPoint_
            || msg.sender == owner(), "HEXLA013");
    }
}
