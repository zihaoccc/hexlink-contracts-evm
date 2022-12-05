// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../interfaces/INonce.sol";
import "../interfaces/IHexlink.sol";
import "../interfaces/IInitializable.sol";

contract HexlinkHelper {
    using Address for address;

    event Deploy(bytes32 indexed salt, address indexed base, address account);

    function redeploy(bytes32 name, address impl, bytes calldata initData) public returns(address) {
        address account = Clones.cloneDeterministic(impl, name);
        IInitializable(account).init(initData);
        emit Deploy(name, impl, account);
        return account;
    }

    function redeployAndReset(
        address impl,
        bytes32 name,
        bytes calldata initData,
        address hexlink,
        AuthProof[] calldata proofs
    ) external {
        address account = redeploy(name, impl, initData);
        uint96 nonce = INonce(hexlink).nonce(name);
        Request memory request = Request(
            name, IHexlink.reset.selector, abi.encode(account), nonce
        );
        IHexlink(hexlink).reset(request, proofs);
    }
}
