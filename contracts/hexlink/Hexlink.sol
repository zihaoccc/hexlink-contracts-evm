// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../lib/IInitializable.sol";
import "../auth/HexlinkAuth.sol";

struct AccountState {
    address account;
    uint96 nonce;
}

struct PrevAuthProof {
    uint256 verifiedAt;
    uint256 authType;
}

struct AppStorage {
    // auth type => oracle address
    mapping(uint256 => address) oracles;
    // account name => account state
    mapping(bytes32 => AccountState) states;
    // request id => prev auth proof
    mapping(bytes32 => PrevAuthProof) proofs;
}

contract Hexlink is IHexlink, HexlinkAuth, SafeOwnable {
    using Address for address;

    event SetOracle(uint256 indexed authType, address indexed oracle);
    event Reset(bytes32 indexed name, address indexed account);

    address immutable accountImpl_;
    AppStorage internal s;

    constructor(address _accountImpl, address _owner) {
        accountImpl_ = _accountImpl;
        OwnableStorage.layout().owner = _owner;
    }

    function oracle(uint256 authType) public view returns (address) {
        return s.oracles[authType];
    }

    function setOracle(uint256 authType, address newOracle) external onlyOwner {
        require(authType != 0, "HEXL033"); // 0 is reserved for account signature check
        s.oracles[authType] = newOracle;
        emit SetOracle(authType, newOracle);
    }

    function accountImpl() external view returns (address) {
        return accountImpl_;
    }

    function nonce(bytes32 name) public view returns (uint96) {
        return s.states[name].nonce;
    }

    function twoStageLock(uint256 /* authType */) public pure returns (uint256) {
        return 259200; // 3 days
    }

    function addressOfName(bytes32 name) public view returns (address) {
        address account = s.states[name].account;
        return account == address(0) ? _defaultAccount(name) : account;
    }

    function deploy(Request calldata request, AuthProof calldata proof) external {
        _validateRequest(request, proof, s.states[request.name]);
        address account = Clones.cloneDeterministic(accountImpl_, request.name);
        IInitializable(account).init(request.params);
    }

    function reset(
        Request calldata request,
        AuthProof calldata proof
    ) external {
        AccountState memory state = s.states[request.name];
        require(!_initiated(request.name, state.account), "HEXL003");
        _validateRequest(request, proof, state);
        _reset(request.name, request.params);
        s.states[request.name].nonce = state.nonce + 1;
    }

    function reset2Fac(
        Request calldata request,
        AuthProof calldata proof1,
        AuthProof calldata proof2
    ) external {
        AccountState memory state = s.states[request.name];
        require(_initiated(request.name, state.account), "HEXL003");
        _validateRequest2Fac(request, proof1, proof2, state);
        _reset(request.name, request.params);
        s.states[request.name].nonce = state.nonce + 1;
    }

    function reset2Stage(Request calldata request, AuthProof calldata proof) external {
        AccountState memory state = s.states[request.name];
        require(_initiated(request.name, state.account), "HEXL003");
        bytes32 requestId = _requestId(request);
        PrevAuthProof memory prev = s.proofs[requestId];
        if (prev.verifiedAt == 0) { // stage 1
            _validateRequest(request, proof, state);
            s.proofs[requestId].verifiedAt = block.timestamp;
            s.proofs[requestId].authType = proof.authType;
        } else { // stage 2
            _validateRequest2Stage(request, proof, prev, state);
            _reset(request.name, request.params);
            s.states[request.name].nonce = state.nonce + 1;
            s.proofs[requestId].verifiedAt = 0;
        }
    }

    // this will invalidate all pending requests
    function bumpNonce(Request calldata request, AuthProof calldata proof) external {
        AccountState memory state = s.states[request.name];
        _validateRequest(request, proof, state);
        s.states[request.name].nonce = state.nonce + 1;
    }

    function _reset(bytes32 name, bytes calldata params) internal {
        address account = abi.decode(params, (address));
        require(account != address(0), "HEXL003");
        s.states[name].account = account;
        emit Reset(name, account);
    }

    function _validateRequest(
        Request calldata request,
        AuthProof calldata proof,
        AccountState memory state
    ) private view {
        require(request.name == proof.name, "HEXL020");
        require(request.func == msg.sig, "HEXL021");
        require(state.nonce == request.nonce, "HEXL020");
        address validator = proof.authType == 0 ? state.account : oracle(proof.authType);
        _validateAuthProof(_requestId(request), validator, proof);
    }

    function _validateRequest2Fac(
        Request calldata request,
        AuthProof calldata proof1,
        AuthProof calldata proof2,
        AccountState memory state
    ) private view {
        _validateRequest(request, proof1, state);
        _validateRequest(request, proof2, state);
        require(proof1.authType != proof2.authType, "HEXL031"); // 2-fac
        // one of the auth proof must be signed by account admin
        // in case 3rd-party oracle is hacked
        require(proof1.authType == 0 || proof2.authType == 0, "HEXL032");
    }

    function _validateRequest2Stage(
        Request calldata request,
        AuthProof calldata proof,
        PrevAuthProof memory prevProof,
        AccountState memory state
    ) private view {
        _validateRequest(request, proof, state);
        // There are four cases here:
        // prevProof.authType == 0 && proof.authType == 0 => invalid
        // prevProof.authType != 0 && proof.authType == 0 => 2-fac
        // prevProof.authType == 0 && proof.authType != 0 => 2-fac
        // prevProof.authType != 0 && proof.authType != 0 => 2-stage
        require(prevProof.authType != 0 || proof.authType != 0, "HEXL008");
        if (prevProof.authType != 0 && proof.authType != 0) { // 2-stage
            uint256 lockTime = twoStageLock(proof.authType);
            require(block.timestamp > prevProof.verifiedAt + lockTime, "HEXL030");
        }
    }

    function _initiated(bytes32 name, address account) private view returns(bool initiated) {
        return account != address(0) || _defaultAccount(name).isContract();
    }

    function _defaultAccount(bytes32 name) private view returns(address) {
        return Clones.predictDeterministicAddress(accountImpl_, name);
    }

    function _requestId(Request calldata request) private view returns(bytes32) {
        return keccak256(abi.encode(request, address(this), block.chainid));
    }
}
