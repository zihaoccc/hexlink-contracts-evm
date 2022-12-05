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

    function deploy(Request calldata request, AuthProof calldata proof) external {
        RequestInfo memory info = _buildRequestInfo(request);
        _validate(info, proof);
        address account = Clones.cloneDeterministic(accountBase_, request.name);
        IInitializable(account).init(request.params);
        s.states[request.name].nonce = info.nonce + 1;
    }

    function reset(
        Request calldata request,
        AuthProof[] calldata proofs
    ) external {
        RequestInfo memory info = _buildRequestInfo(request);
        if (proofs.length == 2) {
            _validate2Fac(info, proofs[0], proofs[1]);
        } else { // if not 2-fac, only consume first auth proof
            address defaultAccount = _defaultAccount(request.name);
            // account already deployed or reset, so require 2-stage auth
            if (info.account != defaultAccount || defaultAccount.isContract()) {
                uint256 stage = _validate2Stage(info, proofs[0]);
                if (stage == 1) {
                    return; // pending confirm, not doing anything
                }
            } else { // bootstrap
                _validate(info, proofs[0]);
            }
        }
        _reset(request.name, request.params);
        s.states[request.name].nonce = info.nonce + 1;
    }

    // this will invalidate pending 2-stage request
    function bumpNonce(Request calldata request, AuthProof calldata proof) public {
        RequestInfo memory info = _buildRequestInfo(request);
        _validate(info, proof);
        s.states[request.name].nonce = info.nonce + 1;
    }

    function _buildRequestInfo(
        Request calldata request
    ) internal view returns (RequestInfo memory) {
        AccountState memory state = s.states[request.name];
        require(request.func == msg.sig, "HEXL021");
        require(state.nonce == request.nonce, "HEXL020");
        return RequestInfo(
            keccak256(abi.encode(request, address(this), block.chainid)),
            _addressOfName(request.name, state.account),
            state.nonce
        );
    }

    function _reset(bytes32 name, bytes calldata params) internal {
        address account = abi.decode(params, (address));
        require(account != address(0), "HEXL003");
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
