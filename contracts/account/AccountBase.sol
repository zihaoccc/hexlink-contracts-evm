//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

/* solhint-disable avoid-low-level-calls */

import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Upgrade.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract AccountBase is ERC1967Upgrade {
    struct BasicUserOp {
        address to;
        uint256 value;
        bytes callData;
        uint256 callGasLimit;
    }

    using Address for address;

    receive() external payable { }

    fallback(bytes calldata) external returns (bytes memory) {
        // for ERC1155 and ERC3525
        return abi.encode(msg.sig);
    }

    function admin() external view returns(address) {
        return _getAdmin();
    }

    function beacon() external view returns(address) {
        return _getBeacon();
    }

    function _execBatch(BasicUserOp[] calldata ops) internal virtual {
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
