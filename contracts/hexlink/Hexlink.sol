// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../account/IAccount.sol";
import "../oracle/IIdentityOracle.sol";

contract Hexlink {
    event SetAccount(bytes32 indexed nameHash, address indexed account);

    address immutable accountProxy_;
    address immutable oracle_;
    address immutable beacon_;
    mapping(bytes32 => address) private overrides_;

    constructor(address _oracle, address _beacon) {
        accountProxy_ = Create2.deploy(0, bytes32(0), type(AccountProxy).creationCode);
        oracle_ = _oracle;
        beacon_ = _beacon;
    }

    function accountProxy() external view returns (address) {
        return accountProxy_;
    }

    function beacon() external view returns (address) {
        return beacon_;
    }

    function oracle() external view returns (address) {
        return oracle_;
    }

    function deploy(
        bytes32 nameHash,
        address owner,
        bytes memory authProof
    ) external {
        require(IIdentityOracle(oracle_).validate(nameHash, authProof), "HEXL001");
        address account = _deploy(nameHash, owner, false);
        emit SetAccount(nameHash, account);
    }

    function resetAccount(
        bytes32 nameHash,
        address ownerOrAccount,
        bool isAccount,
        bytes memory authProof
    ) external {
        require(IIdentityOracle(oracle_).validate(nameHash, authProof), "HEXL001");
        require(ownerOrAccount != address(0), "HEXL002");
        address account = isAccount
            ? ownerOrAccount
            : _deploy(nameHash, ownerOrAccount, true);
        overrides_[nameHash] = account;
        emit SetAccount(nameHash, account);
    }

    function addressOfName(bytes32 nameHash) external view returns (address) {
        address account = overrides_[nameHash];
        if (account == address(0)) {
            return Clones.predictDeterministicAddress(accountProxy_, nameHash);
        } else {
            return account;
        }
    }

    function _deploy(
        bytes32 nameHash,
        address admin,
        bool reset
    ) private returns (address payable cloned) {
        bytes32 salt = reset
            ? keccak256(abi.encodePacked(nameHash, block.timestamp))
            : nameHash;
        cloned = payable(Clones.cloneDeterministic(accountProxy_, salt));
        IAccount(cloned).init(admin, beacon_, "");
    }
}
