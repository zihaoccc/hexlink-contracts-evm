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

contract Hexlink is SafeOwnable {
    using Address for address;

    event SetAccount(bytes32 indexed nameHash, address indexed account);
    event SetOracle(address indexed oracle);

    address immutable accountProxy_;

    constructor(address _oracle) {
        accountProxy_ = Create2.deploy(0, bytes32(0), type(AccountProxy).creationCode);
        HexlinkStorage.layout().oracle = _oracle;
    }

    function accountProxy() external view returns (address) {
        return accountProxy_;
    }

    function oracle() external view returns (address) {
        return HexlinkStorage.layout().oracle;
    }

    function updateOracle(address newOracle) onlyOwner external {
        HexlinkStorage.layout().oracle = newOracle;
        emit SetOracle(newOracle);
    }

    function deploy(
        bytes32 nameHash,
        bytes memory initData,
        bytes memory authProof,
        bool forceDeploy
    ) external {
        HexlinkStorage.Layout storage s = HexlinkStorage.layout();
        require(IIdentityOracle(s.oracle).validate(nameHash, authProof), "HEXL001");
        address account = _predictAddress(nameHash);
        if (account.isContract()) { // already deployed, redeploy
            require(forceDeploy, "HEXL003");
            bytes32 salt = keccak256(abi.encodePacked(nameHash, block.timestamp));
            account = Clones.cloneDeterministic(accountProxy_, salt);
            s.overrides[nameHash] = account;
        } else {
            account = Clones.cloneDeterministic(accountProxy_, nameHash);
        }
        IInitializable(account).init(initData);
        emit SetAccount(nameHash, account);
    }

    function resetAccount(
        bytes32 nameHash,
        address account,
        bytes memory authProof
    ) external {
        HexlinkStorage.Layout storage s = HexlinkStorage.layout();
        require(IIdentityOracle(s.oracle).validate(nameHash, authProof), "HEXL001");
        require(account != address(0), "HEXL002");
        s.overrides[nameHash] = account;
        emit SetAccount(nameHash, account);
    }

    function addressOfName(bytes32 nameHash) external view returns (address) {
        address account = HexlinkStorage.layout().overrides[nameHash];
        return account == address(0) ? _predictAddress(nameHash) : account;
    }

    function _predictAddress(bytes32 salt) private view returns (address) {
        return Clones.predictDeterministicAddress(accountProxy_, salt);
    }
}
