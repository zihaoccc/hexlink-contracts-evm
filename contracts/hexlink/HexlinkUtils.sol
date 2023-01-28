// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "../utils/Op.sol";

abstract contract HexlinkUtils {
    using Address for address;

    function process(Op[] calldata ops) external payable {
        for (uint256 i = 0; i < ops.length; i++) {
            Op memory op = ops[i];
            (
                bool success,
                bytes memory data
            ) = op.to.call{
                value: op.value,
                gas: op.callGasLimit == 0 ? gasleft() : op.callGasLimit
            }(op.callData);
            Address.verifyCallResult(success, data, "HEXL023");
        }
    }
}
