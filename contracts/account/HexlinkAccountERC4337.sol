//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./LibAccountStorage.sol";
import "./HexlinkAccountBase.sol";

contract HexlinkAccountERC4337 is HexlinkAccountBase, BaseWallet {
    struct AccountStorage {
        bool initialized;
        address entryPoint;
        uint64 nonce;
    }

    using ECDSA for bytes32;

    event SetEntryPoint(address indexed newEntryPoint);

    AccountStorage internal s;

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 constant private MAGICVALUE = 0x1626ba7e;

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(address admin, address beacon, bytes memory data, address entrypoint) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
        _updateEntryPoint(entrypoint);
    }

    function execBatch(BasicUserOp[] calldata ops) public override virtual {
        require(msg.sender == s.entryPoint || msg.sender == _getAdmin(), "HEXL014");
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) public override virtual {
        // In EIP4337 case, we assume user will use entrypoint to send txes in default 
        // so here we alway check entrypoint contract address first
        require(msg.sender == s.entryPoint || msg.sender == _getAdmin(), "HEXL015");
        _exec(op);
    }

    function nonce() public view virtual returns (uint256) {
        return s.nonce;
    }

    function entryPoint() public view virtual returns (address) {
        return s.entryPoint;
    }

    function updateEntryPoint(address newEntryPoint) external virtual {
        _requireFromSelfOrAdmin();
        _updateEntryPoint(newEntryPoint);
    }

    function _validateAndUpdateNonce(UserOperation calldata userOp) internal override virtual {
        require(s.nonce++ == userOp.nonce, "HEXL008");
    }

    function _updateEntryPoint(address newEntryPoint) internal virtual {
        s.entryPoint = newEntryPoint;
        emit SetEntryPoint(newEntryPoint);
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 requestId, address)
    internal override virtual returns (uint256 deadline) {
        address signer = _getAdmin();
        bytes32 reqHash = requestId.toEthSignedMessageHash();
        if (Address.isContract(signer)) {
            try IERC1271(signer).isValidSignature(reqHash, userOp.signature) returns (bytes4 returnvalue) {
                require(returnvalue == MAGICVALUE, "HEXL009");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("HEXL006");
            }
        } else {
            require(signer == reqHash.recover(userOp.signature), "HEXL010");
        }
        return 0;
    }

    function _requireFromEntryPoint() internal view override {
        require(msg.sender == s.entryPoint, "HEXL010");
    }
}
