//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";

contract GasPayer {
    function _handleGasPayment(
        uint256 gasUsed,
        address token,
        uint256 price,
        address payable refundReceiver
    ) internal returns (uint256 payment) {
        address payable receiver = refundReceiver == address(0)
            ? payable(tx.origin)
            : refundReceiver;
        if (price == 0) {
            require(token == address(0), "HEXLU003");
            price = tx.gasprice;
        }
        payment = gasUsed * price;
        _transfer(token, receiver, payment);
    }

    function _transfer(address token, address payable receiver, uint256 amount) internal {
        if (token == address(0)) {
            Address.sendValue(receiver, amount);
        } else {
            require(_transferToken(token, receiver, amount), "HEXLU002");
        }
    }

    /// @dev Transfers a token and returns if it was a success
    /// @param token Token that should be transferred
    /// @param receiver Receiver to whom the token should be transferred
    /// @param amount The amount of tokens that should be transferred
    function _transferToken(
        address token,
        address receiver,
        uint256 amount
    ) internal returns (bool transferred) {
        // 0xa9059cbb - keccack("transfer(address,uint256)")
        bytes memory data = abi.encodeWithSelector(0xa9059cbb, receiver, amount);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // We write the return value to scratch space.
            // See https://docs.soliditylang.org/en/v0.7.6/internals/layout_in_memory.html#layout-in-memory
            let success := call(sub(gas(), 10000), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            switch returndatasize()
                case 0 {
                    transferred := success
                }
                case 0x20 {
                    transferred := iszero(or(iszero(success), iszero(mload(0))))
                }
                default {
                    transferred := 0
                }
        }
    }
}
