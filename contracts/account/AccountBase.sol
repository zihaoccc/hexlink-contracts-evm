//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

/* solhint-disable avoid-low-level-calls */

import "@solidstate/contracts/access/ownable/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./IAccount.sol";

abstract contract AccountBase is IERC1271, IAccount, Ownable {
    using Address for address;
    using ECDSA for bytes32;

    event Deposit(
        bytes32 indexed ref,
        address indexed receipt,
        address token,
        uint256 amount
    );

    receive() external payable { }

    fallback(bytes calldata) external returns (bytes memory) {
        // for ERC1155 and ERC3525
        return abi.encode(msg.sig);
    }

    function isValidSignature(
        bytes32 message,
        bytes calldata signature
    ) external override view returns(bytes4) {
        _validateSignature(message, signature);
        return IERC1271.isValidSignature.selector;
    }

    function deposit(
        bytes32 ref,
        address receipt,
        address token,
        uint256 amount
    ) external {
         _validateCaller();
        if (token == address(0)) {
            Address.sendValue(payable(receipt), amount);
        } else {
            IERC20(token).transfer(receipt, amount);
        }
        emit Deposit(ref, receipt, token, amount);
    }

    function execBatch(Op[] calldata ops) external payable override {
        _validateCaller();
        uint256 opsLen = ops.length;
        for (uint256 i = 0; i < opsLen; i++) {
            _exec(ops[i]);
        }
    }

    function exec(Op calldata op) external payable override {
        _validateCaller();
        _exec(op);
    }

    function _exec(Op calldata op) internal {
        (
            bool success,
            bytes memory data
        ) = op.to.call{
            value: op.value,
            gas: op.callGasLimit == 0 ? gasleft() : op.callGasLimit
        }(op.callData);
        Address.verifyCallResult(success, data, "HEXLA001");
    }

    function _validateSignature(bytes32 message, bytes calldata signature) internal view {
        address signer = owner();
        bytes32 reqHash = message.toEthSignedMessageHash();
        if (signer.isContract()) {
            try IERC1271(signer).isValidSignature(reqHash, signature) returns (bytes4 returnvalue) {
                require(returnvalue == IERC1271.isValidSignature.selector, "HEXLA002");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("HEXLA003");
            }
        } else {
            require(signer == reqHash.recover(signature), "HEXLA004");
        }
    }

    function _validateCaller() internal virtual;
}
