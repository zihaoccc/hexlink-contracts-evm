// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@solidstate/contracts/access/ownable/OwnableStorage.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "./HexlinkImpl.sol";

contract HexlinkUpgradeableV2ForTest is HexlinkImpl, UUPSUpgradeable {
    constructor(address accountBase) HexlinkImpl(accountBase) { }

    function implementation() external view returns (address) {
        return _getImplementation();
    }

    function name() external pure returns (string memory) {
        return "HexlinkUpgradeableV2ForTest";
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal view onlyOwner override { }
}
