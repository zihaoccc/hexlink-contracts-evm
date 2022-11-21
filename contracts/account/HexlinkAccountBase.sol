//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./BasicUserOp.sol";
import "./ProxyManager.sol";

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/utils/Address.sol";
import "./LibAccountStorage.sol";

abstract contract HexlinkAccountBase is ProxyManager {
    using Address for address;

    receive() external payable { }

    fallback(bytes calldata) external returns (bytes memory) {
        // for ERC1155 and ERC3525
        return abi.encode(msg.sig);
    }

    function execBatch(BasicUserOp[] calldata ops) external onlyAdmin {
        _execBatch(ops);
    }

    function exec(BasicUserOp calldata op) external onlyAdmin {
        _exec(op);
    }

    function _execBatch(BasicUserOp[] calldata ops) internal {
        uint256 opsLen = ops.length;
        for (uint256 i = 0; i < opsLen; i++) {
            _exec(ops[i]);
        }
    }

    function _exec(BasicUserOp calldata op) internal {
        require(address(this).balance >= op.value, "HEXL002");
        (
            bool success,
            bytes memory data
        ) = op.to.call{value: op.value, gas: op.callGasLimit}(op.callData);
        op.to.verifyCallResultFromTarget(success, data, "HEXL003");
    }
}
