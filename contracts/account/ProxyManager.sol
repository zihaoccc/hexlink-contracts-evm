// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";

abstract contract ProxyManager is ERC1967Upgrade {
    function admin() external view returns(address) {
        return _getAdmin();
    }

    function beacon() external view returns(address) {
        return _getBeacon();
    }

    function changeAdmin(address newAdmin) external {
        _requireFromSelfOrAdmin();
        _changeAdmin(newAdmin);
    }

    function upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) external {
        _requireFromSelfOrAdmin();
        _upgradeBeaconToAndCall(newBeacon, data, forceCall);
    }

    function _requireFromSelfOrAdmin() internal view virtual {
        require(msg.sender == address(this) || msg.sender == _getAdmin(), "HEXL013");
    }
}