// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./IHexlink.sol";

contract HexlinkHelper {
    using Address for address;

    event Deploy(bytes32 indexed name, address indexed impl, address account);

    function deploy(bytes32 name, address impl, bytes calldata txData) public returns(address) {
        address account = Clones.cloneDeterministic(impl, name);
        account.functionCall(txData);
        emit Deploy(name, impl, account);
        return account;
    }

    function deployAndReset(
        address impl,
        bytes32 name,
        bytes calldata txData,
        address hexlink,
        AuthProof[] calldata proofs
    ) external {
        address account = deploy(name, impl, txData);
        if (proofs.length == 2) {
            IHexlink(hexlink).reset2Fac(name, account, proofs[0], proofs[1]);
        } else if (proofs.length == 1) {
            IHexlink(hexlink).reset2Stage(name, account, proofs[0]);
        } else {
            revert("HEXL014");
        }
    }
}
