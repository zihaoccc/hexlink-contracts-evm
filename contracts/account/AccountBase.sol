//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../utils/Initializable.sol";
import "../interfaces/IAccount.sol";

abstract contract AccountBase is IAccount, ERC1967Upgrade, Initializable {
    using ECDSA for bytes32;

    struct BasicUserOp {
        address to;
        uint256 value;
        bytes callData;
        uint256 callGasLimit;
    }

    using Address for address;

    receive() external payable { }

    fallback(bytes calldata) external returns (bytes memory) {
        // for ERC1155 and ERC3525
        return abi.encode(msg.sig);
    }

    function admin() external override view returns(address) {
        return _getAdmin();
    }

    function beacon() external view returns(address) {
        return _getBeacon();
    }

    function isValidSignature(
        bytes32 message,
        bytes calldata signature
    ) external override view returns(bytes4) {
        _validateSignature(message, signature);
        return IERC1271.isValidSignature.selector;
    }

    function _execBatch(BasicUserOp[] calldata ops) internal virtual {
        uint256 opsLen = ops.length;
        for (uint256 i = 0; i < opsLen; i++) {
            _exec(ops[i]);
        }
    }

    function _exec(BasicUserOp calldata op) internal {
        require(address(this).balance >= op.value, "HEXL002");
        (
            bool success,
            bytes memory data
        ) = op.to.call{value: op.value, gas: op.callGasLimit}(op.callData);
        op.to.verifyCallResultFromTarget(success, data, "HEXL003");
    }

    function _validateSignature(bytes32 message, bytes calldata signature) internal view {
        address signer = _getAdmin();
        bytes32 reqHash = message.toEthSignedMessageHash();
        if (Address.isContract(signer)) {
            try IERC1271(signer).isValidSignature(reqHash, signature) returns (bytes4 returnvalue) {
                require(returnvalue == IERC1271.isValidSignature.selector, "HEXL009");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("HEXL006");
            }
        } else {
            require(signer == reqHash.recover(signature), "HEXL010");
        }
    }
}
