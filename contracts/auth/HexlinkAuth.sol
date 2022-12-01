// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../lib/IInitializable.sol";
import "../auth/IIdentityOracle.sol";
import "./Request.sol";

library HexlinkAuthStorage {
    struct Layout {
        mapping(uint256 => address) oracles;
        mapping(bytes32 => uint256) nonces;
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

    uint256 constant AUTH_TTL = 3600; // one hour

    event SetOracle(uint256 indexed authType, address indexed oracle);

    function oracle(uint256 authType) public view returns (address) {
        return HexlinkAuthStorage.layout().oracles[authType];
    }

    function nonce(bytes32 nameHash) public view returns (uint256) {
        return HexlinkAuthStorage.layout().nonces[nameHash];
    }

    function _setOracle(uint256 authType, address newOracle) internal {
        HexlinkAuthStorage.layout().oracles[authType] = newOracle;
        emit SetOracle(authType, newOracle);
    }

    function _validateRequest(HexlinkRequest memory request) internal {
        HexlinkAuthStorage.Layout storage s = HexlinkAuthStorage.layout();
        require(s.nonces[request.nameHash]++ == request.nonce, "HEXL020");
        require(request.functionToCall == msg.sig, "HEXL021");
        require(
            request.verifiedAt < block.timestamp &&
                request.verifiedAt > block.timestamp - AUTH_TTL,
            "HEXL021"
        );
        _validateSignature(s.oracles[request.authType], request);
    }

    function _validateSignature(address oracle_, HexlinkRequest memory request) view internal {
        RequestToSign memory requestToSign = RequestToSign({
            nameHash: request.nameHash,
            functionToCall: request.functionToCall,
            functionParamsHash: keccak256(request.functionParams),
            nonce: request.nonce,
            verifiedAt: request.verifiedAt,
            authType: request.authType,
            oracle: oracle_,
            chainId: block.chainid
        });
        bytes32 message = keccak256(abi.encode(requestToSign));
        require(
            IIdentityOracle(oracle_).validate(message, request.verifiers, request.signature),
            "HEXL021"
        );
    }
}
