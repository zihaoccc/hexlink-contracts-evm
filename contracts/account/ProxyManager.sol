// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

abstract contract ProxyManager is ERC1967Upgrade {
    modifier onlyAdmin() {
        require(msg.sender == address(this) || msg.sender == _getAdmin(), "HEXL001");
        _;
    }

    function getAdmin() external view returns(address) {
        return _getAdmin();
    }

    function getBeacon() external view returns(address) {
        return _getBeacon();
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        _changeAdmin(newAdmin);
    }

    function upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) external onlyAdmin {
        _upgradeBeaconToAndCall(newBeacon, data, forceCall);
    }
}