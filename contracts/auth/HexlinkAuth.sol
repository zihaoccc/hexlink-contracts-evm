// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../interfaces/IHexlink.sol";

abstract contract HexlinkAuth {
    function _validateAuthProof(
        bytes32 requestId,
        address validator,
        AuthProof calldata proof
    ) internal view {
        require(proof.requestId == requestId, "HEXL022");
        require(proof.expiredAt > block.timestamp, "HEXL023");
        _validateSignature(validator, proof);
    }

    function _validateSignature(address validator, AuthProof calldata proof) private view {
        bytes32 message = keccak256(abi.encode(_pack(proof)));
        try IERC1271(validator).isValidSignature(message, proof.signature) returns (bytes4 returnvalue) {
            require(returnvalue == IERC1271.isValidSignature.selector, "HEXL009");
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("HEXL006");
        }
    }

    function _pack(AuthProof calldata proof) private pure returns (bytes memory ret) {
        bytes calldata sig = proof.signature;
        // copy directly the proof from calldata up to (but not including) the signature.
        // this encoding depends on the ABI encoding of calldata, but is much lighter to copy
        // than referencing each field separately.
        assembly {
            let ofs := proof
            let len := sub(sub(sig.offset, ofs), 32)
            ret := mload(0x40)
            mstore(0x40, add(ret, add(len, 32)))
            mstore(ret, len)
            calldatacopy(add(ret, 32), ofs, len)
        }
    }
}
