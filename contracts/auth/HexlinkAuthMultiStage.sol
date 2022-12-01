// SPDX-License-Identifier: MIT
// Hexlink Contracts

import "./HexlinkAuth.sol";
import "./Request.sol";

pragma solidity ^0.8.0;

library HexlinkAuthMultiStageStorage {
    struct Layout {
        // nameHash -> function -> AuthState
        mapping(bytes32 => mapping(bytes4 => AuthState)) states;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('hexlink.contracts.storage.HexlinkAuthMultiStageStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

abstract contract HexlinkAuthMultiStage is HexlinkAuth {
    uint64 constant MIN_AUTH_ATTEMPT_GAP = 3600 * 24 * 3; // 3 days

    function _validateRequestMultiStage(
        HexlinkRequest memory request
    ) internal returns(AuthState memory newState) {
        _validateRequest(request);
        HexlinkAuthMultiStageStorage.Layout storage s =
            HexlinkAuthMultiStageStorage.layout();
        newState = _updateAuthState(
            request,
            s.states[request.nameHash][request.functionToCall]
        );
        s.states[request.nameHash][request.functionToCall] = newState;
        return newState;
    }

    function _clearAuthState(bytes32 nameHash, bytes4 functionSelector) internal {
        HexlinkAuthMultiStageStorage.Layout storage s =
            HexlinkAuthMultiStageStorage.layout();
        s.states[nameHash][functionSelector].totalAuthAttempts = 0;
        s.states[nameHash][functionSelector].totalAuthMethods = 0;
    }

    function _updateAuthState(
        HexlinkRequest memory request,
        AuthState memory state
    ) internal view returns(AuthState memory) {
        bytes32 paramsHash = keccak256(request.functionParams);
        if (state.totalAuthAttempts > 0) {
            require(state.lastParamsHash == paramsHash, "HEXL030");
            require(state.lastVerifiedAt + MIN_AUTH_ATTEMPT_GAP < block.timestamp, "HEXL031");
        }
        state.lastParamsHash = paramsHash;
        state.totalAuthAttempts++;
        state.lastVerifiedAt = request.verifiedAt;
        return state;
    }
}