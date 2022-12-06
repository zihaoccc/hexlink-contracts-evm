// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../interfaces/IInitializable.sol";
import "../interfaces/IHexlink.sol";
import "../interfaces/INonce.sol";
import "../auth/HexlinkAuth.sol";

struct AccountState {
    address account;
    uint96 nonce;
}

struct AppStorage {
    // account name => account state
    mapping(bytes32 => AccountState) states;
}

contract Hexlink is IHexlink, INonce, HexlinkAuth, SafeOwnable {
    using Address for address;

    event Reset(bytes32 indexed name, address indexed account);

    address immutable accountBase_;
    AppStorage internal s;

    constructor(address _accountBase) {
        accountBase_ = _accountBase;
    }

    function setOracles(
        uint256[] memory authTypes,
        address[] memory oracles
    ) external onlyOwner {
        _setOracles(authTypes, oracles);
    }

    function nonce(bytes32 name) external override view returns (uint96) {
        return s.states[name].nonce;
    }

    function accountBase() external override view returns (address) {
        return accountBase_;
    }

    function addressOfName(bytes32 name) public view returns (address) {
        return _addressOfName(name, s.states[name].account);
    }

    // this will invalidate pending 2-stage request
    function bumpNonce(Request calldata request, AuthProof calldata proof) public {
        RequestInfo memory info = _buildRequestInfo(request);
        _validate(info, proof);
        s.states[request.name].nonce = info.nonce + 1;
    }

    // this will deploy default account contract
    // only first factor is required
    function deploy(Request calldata request, AuthProof calldata proof) external {
        bumpNonce(request, proof);
        address account = Clones.cloneDeterministic(accountBase_, request.name);
        IInitializable(account).init(request.params);
    }

    // reset name to account mapping when account is not initiated
    // only first factor is required
    function reset(
        Request calldata request,
        AuthProof calldata proof
    ) external {
        RequestInfo memory info = _buildRequestInfo(request);
        address defaultAccount = _defaultAccount(request.name);
        require(
            info.account == defaultAccount && !defaultAccount.isContract(),
            "HEXL009"
        );
        _validate(info, proof);
        _reset(request.name, request.params);
        s.states[request.name].nonce = info.nonce + 1;
    }

    // reset name to account mapping with 2-fac
    // when account is already initiated
    // proof1 must be first factor from oracle
    // proof2 must be second factor from account admin
    function reset2Fac(
        Request calldata request,
        AuthProof calldata proof1,
        AuthProof calldata proof2
    ) external {
        RequestInfo memory info = _buildRequestInfo(request);
        _validate2Fac(info, proof1, proof2);
        _reset(request.name, request.params);
        s.states[request.name].nonce = info.nonce + 1;
    }
 
    // reset name to account mapping with 2-stage
    // when account is already initiated
    // If it's first factor for stage one, we will not
    // reset but just validate and record the auth proof.
    // In this case, nonce will not be updated.
    // If it's second factor for stage two, we will
    // validate the proof, reset the account and bump
    // the nonce.
    function reset2Stage(
        Request calldata request,
        AuthProof calldata proof
    ) external {
        RequestInfo memory info = _buildRequestInfo(request);
        uint256 stage = _validate2Stage(info, proof);
        if (stage == 2) {
            _reset(request.name, request.params);
            s.states[request.name].nonce = info.nonce + 1;
        }
    }

    function _buildRequestInfo(
        Request calldata request
    ) private view returns (RequestInfo memory) {
        AccountState memory state = s.states[request.name];
        require(request.func == msg.sig, "HEXL010");
        require(state.nonce == request.nonce, "HEXL011");
        return RequestInfo(
            keccak256(abi.encode(request, address(this), block.chainid)),
            _addressOfName(request.name, state.account),
            state.nonce
        );
    }

    function _reset(bytes32 name, bytes calldata params) internal {
        address account = abi.decode(params, (address));
        require(account != address(0), "HEXL012");
        s.states[name].account = account;
        emit Reset(name, account);
    }

    function _defaultAccount(bytes32 name) private view returns(address) {
        return Clones.predictDeterministicAddress(accountBase_, name);
    }

    function _addressOfName(
        bytes32 name,
        address alt
    ) internal view returns (address) {
        return alt == address(0) ? _defaultAccount(name) : alt;
    }
}
