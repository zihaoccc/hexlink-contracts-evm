// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";

/* solhint-disable no-inline-assembly */

/**
    * User Operation struct
    * @param sender the sender account of this request
    * @param nonce unique value the sender uses to verify it is not a replay.
    * @param initCode if set, the account contract will be created by this constructor
    * @param callData the method call to execute on this account.
    * @param verificationGas gas used for validateUserOp and validatePaymasterUserOp
    * @param preVerificationGas gas not calculated by the handleOps method, but added to the gas paid. Covers batch overhead.
    * @param maxFeePerGas same as EIP-1559 gas parameter
    * @param maxPriorityFeePerGas same as EIP-1559 gas parameter
    * @param paymaster if set, the paymaster will pay for the transaction instead of the sender
    * @param paymasterData extra data used by the paymaster for validation
    * @param signature sender-verified signature over the entire request, the EntryPoint address and the chain ID.
    */
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGas;
    uint256 verificationGas;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    address paymaster;
    bytes paymasterData;
    bytes signature;
}

library LibUserOperation {
    using Address for address;
    using ECDSA for bytes32;

    // bytes4(keccak256("isValidSignature(bytes32,bytes)")
    bytes4 constant private MAGICVALUE = 0x1626ba7e;

    function pack(UserOperation calldata req) private pure returns (bytes memory ret) {
        bytes calldata sig = req.signature;
        // copy directly the req from calldata up to (but not including) the signature.
        // this encoding depends on the ABI encoding of calldata, but is much lighter to copy
        // than referencing each field separately.
        assembly {
            let ofs := req
            let len := sub(sub(sig.offset, ofs), 32)
            ret := mload(0x40)
            mstore(0x40, add(ret, add(len, 32)))
            mstore(ret, len)
            calldatacopy(add(ret, 32), ofs, len)
        }
    }

    function hash(UserOperation calldata req) public pure returns (bytes32) {
        return keccak256(pack(req));
    }

    function validateSig(UserOperation calldata req, bytes32 reqId, address signer) public view returns(bool) {
        bytes32 reqHash = reqId.toEthSignedMessageHash();
        if (Address.isContract(signer)) {
            try IERC1271(signer).isValidSignature(reqHash, req.signature) returns (bytes4 returnvalue) {
                require(returnvalue == MAGICVALUE, "HEXL009");
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("HEXL006");
            }
        } else {
            require(signer == reqHash.recover(req.signature), "HEXL010");
        }
    }
}