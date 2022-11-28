// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../lib/IInitializable.sol";
import "../oracle/IIdentityOracle.sol";
import "../oracle/OracleConsumer.sol";

library HexlinkStorage {
    struct Layout {
        address oracle;
        mapping(bytes32 => address) overrides;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('hexlink.contracts.storage.HexlinkStorage');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }
}

contract Hexlink is SafeOwnable, OracleConsumer {
    using Address for address;

    event ResetAccount(bytes32 indexed nameHash, address indexed account);
    event SetOracle(address indexed oracle);

    address immutable accountProxy_;

    constructor(address oracle_, address owner) OracleConsumer(oracle_) {
        accountProxy_ = Create2.deploy(0, bytes32(0), type(AccountProxy).creationCode);
        OwnableStorage.layout().owner = owner;
    }

    function updateOracle(address newOracle) external onlyOwner {
        _updateOracle(newOracle);
    }

    function accountProxy() external view returns (address) {
        return accountProxy_;
    }

    function addressOfName(bytes32 nameHash) external view returns (address) {
        address account = HexlinkStorage.layout().overrides[nameHash];
        return account == address(0) ? _predictAddress(nameHash) : account;
    }

    function deploy(
        bytes32 nameHash,
        bytes memory initData,
        bytes memory authProof
    ) external {
        address account = _predictAddress(nameHash);
        require(!account.isContract(), "HEXL002");
        if (IIdentityOracle(oracle()).validate(nameHash, authProof, 0)) {
          _deploy(nameHash, initData);
        }
    }

    function redeploy(
        bytes32 nameHash,
        bytes memory initData,
        bytes memory authProof
    ) external {
        address account = _predictAddress(nameHash);
        require(account.isContract(), "HEXL002");
        if (IIdentityOracle(oracle()).validate(nameHash, authProof, 1)) {   
            _redeploy(nameHash, initData);
        }
    }

    function resetAccount(
        bytes32 nameHash,
        address account,
        bytes memory authProof
    ) external {
        HexlinkStorage.Layout storage s = HexlinkStorage.layout();
        require(account != address(0), "HEXL003");
        if (IIdentityOracle(s.oracle).validate(nameHash, authProof, 1)) {
            s.overrides[nameHash] = account;
            emit ResetAccount(nameHash, account);
        }
    }

    function _predictAddress(bytes32 salt) private view returns (address) {
        return Clones.predictDeterministicAddress(accountProxy_, salt);
    }

    function _redeploy(
        bytes32 nameHash,
        bytes memory initData
    ) internal returns (address account) {
        bytes32 salt = keccak256(abi.encodePacked(nameHash, block.timestamp));
        account = _deploy(salt, initData);
        HexlinkStorage.layout().overrides[nameHash] = account;
        emit ResetAccount(nameHash, account);
    }

    function _deploy(
        bytes32 salt,
        bytes memory initData
    ) internal returns (address account) {
        account = Clones.cloneDeterministic(accountProxy_, salt);
        IInitializable(account).init(initData);
    }
}
