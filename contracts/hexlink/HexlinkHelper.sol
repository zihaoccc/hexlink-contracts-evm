// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/IHexlink.sol";
import "../lib/IInitializable.sol";

contract HexlinkHelper {
    using Address for address;

    function redeploy(address hexlink, bytes32 name, bytes calldata initData) public {
        address accountImpl = IHexlink(hexlink).accountImpl();
        address account = Clones.cloneDeterministic(accountImpl, name);
        IInitializable(account).init(initData);
    }

    function redeployAndReset(
        address hexlink,
        bytes32 name,
        bytes calldata initData,
        bytes calldata resetCalldata
    ) external {
        redeploy(hexlink, name, initData);
        hexlink.functionCall(resetCalldata, "HEXL010");
    }
}
