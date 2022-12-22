//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./AccountProxy.sol";

contract TestAccountDeployer {

    event Deploy(address indexed account);

    address private base_;

    constructor(address base) {
        base_ = base;
    }

    function deploy(bytes32 name) external {
        address account = Clones.cloneDeterministic(base_, name);
        emit Deploy(account);
    }

    function addressOfName(bytes32 name) external view returns (address) {
        return Clones.predictDeterministicAddress(base_, name);
    }
}