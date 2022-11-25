//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

import "./eip4337/BaseWallet.sol";
import "./eip4337/UserOperation.sol";
import "./AccountBase.sol";

contract HexlinkAccountERC4337 is AccountBase, BaseWallet {
    struct AccountStorage {
        bool initialized;
        address entryPoint;
        uint64 nonce;
    }

    using ECDSA for bytes32;

    event SetEntryPoint(address indexed newEntryPoint);

    AccountStorage internal s;

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
        require(s.nonce++ == userOp.nonce, "HEXL008");
    }

    function _validateSignature(UserOperation calldata userOp, bytes32 requestId, address)
    internal override virtual returns (uint256 deadline) {
        address signer = _getAdmin();
        bytes32 reqHash = requestId.toEthSignedMessageHash();
        if (Address.isContract(signer)) {
            try IERC1271(signer).isValidSignature(reqHash, userOp.signature) returns (bytes4 returnvalue) {
                require(returnvalue == IERC1271.isValidSignature.selector, "HEXL009");
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
}
