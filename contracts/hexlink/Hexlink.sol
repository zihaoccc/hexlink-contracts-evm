// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@solidstate/contracts/access/ownable/SafeOwnable.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import "../account/AccountProxy.sol";
import "../lib/IInitializable.sol";
import "../auth/IIdentityOracle.sol";
import "../auth/HexlinkAuthMultiStage.sol";

library HexlinkStorage {
    struct Layout {
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

contract Hexlink is HexlinkAuthMultiStage, SafeOwnable {
    using Address for address;

    event ResetAccountAttempt(bytes32 indexed nameHash, uint256 attempt);
    event ResetAccount(bytes32 indexed nameHash, address indexed account);

    address immutable accountProxy_;

    constructor(address owner) {
        accountProxy_ = Create2.deploy(0, bytes32(0), type(AccountProxy).creationCode);
        OwnableStorage.layout().owner = owner;
    }

    function accountProxy() external view returns (address) {
        return accountProxy_;
    }

    function setOracle(uint256 authType, address oracle) external onlyOwner {
        _setOracle(authType, oracle);
    }

    function addressOfName(bytes32 nameHash) external view returns (address) {
        address account = HexlinkStorage.layout().overrides[nameHash];
        return account == address(0) ? _predictAddress(nameHash) : account;
    }

    function deploy(HexlinkRequest calldata request) external {
        _validateRequest(request);
        address account = _predictAddress(request.nameHash);
        require(!account.isContract(), "HEXL001");
        _deploy(request.nameHash, request.functionParams);
    }

    function redeploy(HexlinkRequest calldata request) external {
        uint256 attempts = _validateRequestMultiStage(request).totalAuthAttempts;
        if (attempts == 2) {
            address account = _predictAddress(request.nameHash);
            require(account.isContract(), "HEXL002");
            bytes32 salt = keccak256(abi.encodePacked(request.nameHash, block.timestamp));
            account = _deploy(salt, request.functionParams);
            HexlinkStorage.layout().overrides[request.nameHash] = account;
            emit ResetAccount(request.nameHash, account);
        } else {
            emit ResetAccountAttempt(request.nameHash, attempts);
        }
    }

    function resetAccount(HexlinkRequest calldata request) external {
        uint256 attempts = _validateRequestMultiStage(request).totalAuthAttempts;
        if (attempts == 2) {
            _validateRequest(request);
            address account = abi.decode(request.functionParams, (address));
            require(account != address(0), "HEXL003");
            HexlinkStorage.layout().overrides[request.nameHash] = account;
            emit ResetAccount(request.nameHash, account);
        } else {
            emit ResetAccountAttempt(request.nameHash, attempts);
        }
    }

    function _predictAddress(bytes32 salt) private view returns (address) {
        return Clones.predictDeterministicAddress(accountProxy_, salt);
    }

    function _deploy(
        bytes32 salt,
        bytes memory initData
    ) internal returns (address account) {
        account = Clones.cloneDeterministic(accountProxy_, salt);
        IInitializable(account).init(initData);
    }
}
