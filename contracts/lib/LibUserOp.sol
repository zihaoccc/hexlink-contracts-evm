// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../structs/UserOp.sol";

library LibUserOp {
    using ECDSA for bytes32;

    function pack(UserOp calldata req) private pure returns (bytes memory ret) {
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

    function hash(UserOp calldata req) public pure returns (bytes32) {
        return keccak256(pack(req));
    }

    function validateSig(UserOp calldata req, address signer) public view returns(bool) {
        bytes32 reqId = keccak256(abi.encode(hash(req), address(this), block.chainid));
        bytes32 reqHash = reqId.toEthSignedMessageHash();
        return signer == reqHash.recover(req.signature);
    }
}