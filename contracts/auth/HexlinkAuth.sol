// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "../interfaces/IHexlink.sol";

struct PrevAuthProof {
    uint256 verifiedAt;
    uint256 authType;
}

struct RequestInfo {
    bytes32 requestId;
    address account;
    uint96 nonce;
}

library HexlinkAuthStorage {
    struct Layout {
        // auth type => oracle address
        mapping(uint256 => address) oracles;
        // request id => prev auth proof
        mapping(bytes32 => PrevAuthProof) proofs;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('hexlink.contracts.storage.ERC4337Storage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract HexlinkAuth {
    struct AuthConfig {
        uint256 twoStageLock;
        uint256 ttl;
    }

    event SetOracle(uint256 indexed authType, address indexed oracle);

    function oracle(uint256 authType) public view returns (address) {
        return HexlinkAuthStorage.layout().oracles[authType];
    }

    function _setOracle(uint256 authType, address newOracle) internal {
        require(authType != 0 && newOracle != address(0), "HEXL033");
        HexlinkAuthStorage.layout().oracles[authType] = newOracle;
        emit SetOracle(authType, newOracle);
    }

    function authConfig(uint256 /* authType */) public pure returns (AuthConfig memory) {
        return AuthConfig(259200, 3600); // (3 days, 1 hour)
    }

    function _validate2Fac(
        RequestInfo memory info,
        AuthProof calldata proof1, // from oracle
        AuthProof calldata proof2 // from account
    ) internal view {
        _validate(info, proof1);
        _validate(info, proof2);
        require(proof1.authType != 0 && proof2.authType == 0, "HEXL031"); // 2-fac
    }

    function _validate2Stage(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal returns(uint256) {
        _validate(info, proof);
        HexlinkAuthStorage.Layout storage s = HexlinkAuthStorage.layout();
        PrevAuthProof memory prev = s.proofs[info.requestId];
        if (prev.verifiedAt == 0) { // stage 1
            // account singature cannot be first factor
            require(proof.authType != 0, "HEXL010");
            s.proofs[info.requestId].verifiedAt = block.timestamp;
            s.proofs[info.requestId].authType = proof.authType;
            return 1;
        } else { // stage 2
            if (proof.authType != 0) { // 2-stage with oracle
                uint256 lockTime = authConfig(proof.authType).twoStageLock;
                require(block.timestamp > prev.verifiedAt + lockTime, "HEXL030");
            } // else 2-fac
            return 2;
        }
    }

    function _validate(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal view {
        require(
            proof.issuedAt < block.timestamp &&
                proof.issuedAt + authConfig(proof.authType).ttl > block.timestamp,
            "HEXL023"
        );
        bytes32 message = keccak256(abi.encode(info.requestId, proof.issuedAt, proof.authType));
        try IERC1271(_validator(info, proof)).isValidSignature(
            message, proof.signature
        ) returns (bytes4 returnvalue) {
            require(returnvalue == IERC1271.isValidSignature.selector, "HEXL009");
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("HEXL006");
        }
    }

    function _validator(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal view returns(address) {
        return proof.authType == 0 ? info.account : oracle(proof.authType);
    }
}
