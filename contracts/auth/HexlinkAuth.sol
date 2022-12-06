// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../utils/Auth.sol";

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
        keccak256('hexlink.contracts.storage.HexlinkAuthStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract HexlinkAuth {
    using Address for address;

    struct AuthConfig {
        uint256 twoStageLock;
        uint256 ttl;
    }

    event SetOracle(uint256 indexed authType, address indexed oracle);

    function oracle(uint256 authType) public view returns (address) {
        return HexlinkAuthStorage.layout().oracles[authType];
    }

    function _setOracles(uint256[] memory authTypes, address[] memory oracles) internal {
        require(authTypes.length == oracles.length, "HEXL001");
        for (uint256 i = 0; i < authTypes.length; i++) {
            require(authTypes[i] != 0 && oracles[i] != address(0), "HEXL002");
            require(oracles[i].isContract(), "HEXL013");
            HexlinkAuthStorage.layout().oracles[authTypes[i]] = oracles[i];
            emit SetOracle(authTypes[i], oracles[i]);
        }
    }

    function authConfig(uint256 /* authType */) public pure returns (AuthConfig memory) {
        return AuthConfig(259200, 3600); // (3 days, 1 hour)
    }

    function _validate(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal view {
        require(_isValid1stFactor(proof), "HEXL003");
        _validateAuthProof(info, proof);
    }

    function _validate2Fac(
        RequestInfo memory info,
        AuthProof calldata proof1, // from oracle
        AuthProof calldata proof2 // from account
    ) internal view {
        _validate(info, proof1);
        require(_isValid2ndFac(proof2), "HEXL004");
        //[first factor, second factor], order matters
        _validateAuthProof(info, proof2);
    }

    function _validate2Stage(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal returns(uint256) {
        HexlinkAuthStorage.Layout storage s = HexlinkAuthStorage.layout();
        PrevAuthProof memory prev = s.proofs[info.requestId];
        if (prev.verifiedAt == 0) { // stage 1
            _validate(info, proof);
            s.proofs[info.requestId].verifiedAt = block.timestamp;
            s.proofs[info.requestId].authType = proof.authType;
            return 1;
        } else { // stage 2
            if (!_isValid2ndFac(proof)) {
                uint256 lockTime = authConfig(proof.authType).twoStageLock;
                require(block.timestamp > prev.verifiedAt + lockTime, "HEXL005");
            } // else 2-fac
            _validateAuthProof(info, proof);
            return 2;
        }
    }

    function _validateAuthProof(
        RequestInfo memory info,
        AuthProof calldata proof
    ) internal view {
        uint256 ttl = authConfig(proof.authType).ttl;
        require(
            proof.issuedAt < block.timestamp && proof.issuedAt + ttl > block.timestamp,
            "HEXL006"
        );
        bytes32 message = keccak256(abi.encode(info.requestId, proof.issuedAt, proof.authType));
        address validator = proof.authType == 0 ? info.account : oracle(proof.authType);
        try IERC1271(validator).isValidSignature(
            message, proof.signature
        ) returns (bytes4 returnvalue) {
            require(returnvalue == IERC1271.isValidSignature.selector, "HEXL007");
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("HEXL008");
        }
    }

    // in current impl we only allow proof from
    // oracle as first factor
    function _isValid1stFactor(
        AuthProof calldata proof
    ) internal pure returns(bool) {
        return proof.authType != 0;
    }

    // in current impl we only allow proof from
    // account admin as second factor
    function _isValid2ndFac(
        AuthProof calldata proof
    ) internal pure returns(bool) {
        return proof.authType == 0;
    }
}