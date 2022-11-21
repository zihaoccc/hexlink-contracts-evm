// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./account/HexlinkAccount.sol";
import "./oracle/IIdentityOracle.sol";

contract Hexlink {
    using Address for address;

    event SetAccount(bytes32 indexed nameHash, address indexed account);

    address immutable accountImpl_;
    address immutable oracle_;
    mapping(bytes32 => uint256) private versions_;
    mapping(bytes32 => address) private overrides_;

    constructor(address oracle) {
        accountImpl_ = Create2.deploy(0, bytes32(0), type(HexlinkAccount).creationCode);
        oracle_ = oracle;
    }

    function deploy(
        bytes32 nameHash,
        address owner,
        AuthProof memory proof
    ) external {
        require(IIdentityOracle(oracle_).validate(nameHash, proof), "HEXL001");
        _deploy(nameHash, owner);
        emit SetAccount(nameHash, cloned);
    }

    function _deploy(bytes32 nameHash, address owner) private {
        bytes32 salt = keccak256(abi.encodePacked(nameHash, vesions_[nameHash]));
        address payable cloned = payable(Clones.cloneDeterministic(accountImpl_,  salt));
        HexlinkAccount(cloned).initOwner(owner);
    }

    function resetAccount(
        bytes32 nameHash,
        address newOwner,
        AuthProof memory proof,
        bool redeploy
    ) external {
        require(IIdentityOracle(oracle_).validate(nameHash, proof), "HEXL001");
        require(account != address(0), "HEXL002");
        if (redeploy) {
            vesions_[nameHash]++;
            _deploy(nameHash, newOwner);
        } else {
            overrides_[nameHash] = account;
        }
        emit SetAccount(nameHash, account);
    }

    function addressOfName(bytes32 nameHash) external view returns(address) {
        address account = overrides_[nameHash];
        if (account == address(0)) {
            bytes32 salt = keccak256(abi.encodePacked(nameHash, vesions_[nameHash]));
            return Clones.predictDeterministicAddress(accountImpl_, salt);
        } else {
            return account;
        }
    }

    function accountImplementation() external view returns(address) {
        return accountImpl_;
    }
}
