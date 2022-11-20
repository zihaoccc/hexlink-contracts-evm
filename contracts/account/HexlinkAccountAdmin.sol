
//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "../proxy/HexlinkAdmin.sol";
import "../structs/AccountAdminStorage.sol";
import "../structs/UserOp.sol";
import "../lib/LibUserOp.sol";

contract HexlinkAccountAdmin is HexlinkAdmin {
    using LibUserOp for UserOp;

    AccountAdminStorage internal s;

    function handleUserOp(UserOp calldata op) external {
        require(s.nonces[op.user]++ == op.nonce, "HEXL004");
        require(op.validateSig(_getAdmin()), "HEXL005");
        (
            bool success,
            /* bytes memory data */
        ) = op.user.call{value: op.value, gas: op.callGasLimit}(op.callData);
        require(success, "HEXL006");
    }
}