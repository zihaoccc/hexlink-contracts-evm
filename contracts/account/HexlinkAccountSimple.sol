//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./LibAccountStorage.sol";
import "./HexlinkAccountBase.sol";

contract HexlinkAccountSimple is HexlinkAccountBase {
    AccountStorage internal s;

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(address admin, address beacon, bytes memory data) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
    }
}
