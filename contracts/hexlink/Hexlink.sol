// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "./IHexlink.sol";
import "../auth/HexlinkAuth.sol";

contract Hexlink is IHexlink, HexlinkAuth, Ownable {
    struct AccountState {
        address account;
        uint96 nonce;
    }

    using Address for address;

    event Deploy(bytes32 indexed name, address indexed account);
    event Reset(bytes32 indexed name, address indexed account);

    address public immutable accountBase;
    // account name => account state
    mapping(bytes32 => AccountState) states;

    constructor(address _accountBase) {
        accountBase = _accountBase;
    }

    function nonce(bytes32 name) external view returns (uint96) {
        return states[name].nonce;
    }

    function addressOfName(bytes32 name) public view returns (address) {
        return _addressOfName(name, states[name].account);
    }

    function setOracleRegistry(address oracleRegistry) external onlyOwner {
        _setOracleRegistry(oracleRegistry);
    }

    // this will invalidate pending 2-stage request
    function bumpNonce(
        bytes32 name,
        AuthProof calldata proof
    ) external override {
        RequestInfo memory info = _buildRequestInfo(name, "");
        _validate(info, proof);
        states[name].nonce = info.nonce + 1;
    }

    // this will deploy default account contract
    // only first factor is required
    function deploy(
        bytes32 name,
        bytes calldata txData,
        AuthProof calldata proof
    ) external override returns(address) {
        RequestInfo memory info = _buildRequestInfo(name, txData);
        _validate(info, proof);
        address account = Clones.cloneDeterministic(accountBase, name);
        account.functionCall(txData);
        states[name].nonce = info.nonce + 1;
        emit Deploy(name, account);
        return account;
    }

    // reset name to account mapping when account is not initiated
    // only first factor is required
    function reset(
        bytes32 name,
        address account,
        AuthProof calldata proof
    ) external override {
        RequestInfo memory info = _buildRequestInfo(name, abi.encode(account));
        address defaultAccount = _defaultAccount(name);
        require(
            info.account == defaultAccount && !defaultAccount.isContract(),
            "HEXL009"
        );
        _validate(info, proof);
        _reset(name, account);
        states[name].nonce = info.nonce + 1;
    }

    // reset name to account mapping with 2-fac
    // when account is already initiated
    // proof1 must be first factor from oracle
    // proof2 must be second factor from account admin
    function reset2Fac(
        bytes32 name,
        address account,
        AuthProof calldata proof1,
        AuthProof calldata proof2
    ) external override {
        RequestInfo memory info = _buildRequestInfo(name, abi.encode(account));
        _validate2Fac(info, proof1, proof2);
        _reset(name, account);
        states[name].nonce = info.nonce + 1;
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
        bytes32 name,
        address account,
        AuthProof calldata proof
    ) external override {
        RequestInfo memory info = _buildRequestInfo(name, abi.encode(account));
        uint256 stage = _validate2Stage(info, proof);
        if (stage == 2) {
            _reset(name, account);
            states[name].nonce = info.nonce + 1;
        }
    }

    function _buildRequestInfo(
        bytes32 name,
        bytes memory data
    ) private view returns (RequestInfo memory) {
        AccountState memory state = states[name];
        bytes32 requestId = keccak256(
            abi.encode(msg.sig, data, address(this), block.chainid, state.nonce)
        );
        return RequestInfo(
            name,
            requestId,
            _addressOfName(name, state.account),
            state.nonce
        );
    }

    function _reset(bytes32 name, address account) internal {
        require(account != address(0), "HEXL012");
        states[name].account = account;
        emit Reset(name, account);
    }

    function _defaultAccount(bytes32 name) private view returns(address) {
        return Clones.predictDeterministicAddress(accountBase, name);
    }

    function _addressOfName(
        bytes32 name,
        address alt
    ) internal view returns (address) {
        return alt == address(0) ? _defaultAccount(name) : alt;
    }
}
