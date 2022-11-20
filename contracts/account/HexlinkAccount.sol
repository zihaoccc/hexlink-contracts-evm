//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "../proxy/HexlinkProxyManager.sol";
import "../structs/AccountStorage.sol";
import "../structs/UserOp.sol";
import "../lib/LibUserOp.sol";

contract HexlinkAccount is HexlinkProxyManager {
    using LibUserOp for UserOp;

    AccountStorage internal s;

    modifier initializer() {
        require(s.initialized == false, "HEXL001");
        _;
        s.initialized = true;
    }

    function init(address admin, address beacon, bytes memory data) external initializer {
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data);
    }

    function nonce() public view virtual returns (uint256) {
        return s.nonce;
    }

    receive() external payable { }

    fallback(bytes calldata) external returns (bytes memory) {
        // for ERC1155 and ERC3525
        return abi.encode(msg.sig);
    }

    function execBatch(BasicUserOp[] calldata ops) external onlyAdmin {
        uint256 opsLen = ops.length;
        for (uint256 i = 0; i < opsLen; i++) {
            exec(ops[i]);
        }
    }

    function exec(BasicUserOp calldata op) public onlyAdmin {
        (
            bool success,
            /* bytes memory data */
        ) = op.to.call{value: op.value, gas: op.callGasLimit}(op.callData);
        require(success, "HEXL002");
    }
}
