//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    using Address for address;

    event GasPayment(bytes32 indexed request, uint256 payment);

    struct GasObject {
        address token;
        uint256 price;
        uint256 core;
        uint256 base;
        address payable refundReceiver;
    }
    uint256 private nonce_;
    
    function init(address owner) external {
        require(_owner() == address(0), "HEXL015");
        require(owner != address(0), "HEXL019");
        _transferOwnership(owner);
    }

    function nonce() external view returns(uint256) {
        return nonce_;
    }

    function validateAndCall(
        bytes calldata txData,
        GasObject calldata gas, // gas settings
        uint256 _nonce,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        bytes32 requestId = keccak256(abi.encode(txData, gas, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        uint256 gaslimit = gas.core == 0 ? gasleft() : gas.core;
        (bool success,) = address(this).call{gas: gaslimit}(txData);
        require(success, "HEXLA009");
        uint256 payment = handlePayment(gasUsed - gasleft() + gas.base, gas);
        emit GasPayment(requestId, payment);
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }

    function handlePayment(
        uint256 gasUsed,
        GasObject calldata gas
    ) private returns (uint256 payment) {
        // solhint-disable-next-line avoid-tx-origin
        // payment = 21000 or 65000 gas
        // emit = 1200 gas = 375(log) + 375(topic) + 32 * 8(logData) + 64 * 3(memory)
        // buffer = 700 gas
        address payable receiver = gas.refundReceiver == address(0)
            ? payable(tx.origin)
            : gas.refundReceiver;
        if (gas.token == address(0)) {
            uint256 price = gas.price == 0 ? tx.gasprice : gas.price;
            // For ETH we will only adjust the gas price to not be higher than the actual used gas price
            payment = (gasUsed + gas.base) * price;
            Address.sendValue(receiver, payment);
        } else {
            payment = (gasUsed + gas.base) * gas.price;
            require(transferToken(gas.token, receiver, payment), "HEXLA013");
        }
    }

    /// @dev Transfers a token and returns if it was a success
    /// @param token Token that should be transferred
    /// @param receiver Receiver to whom the token should be transferred
    /// @param amount The amount of tokens that should be transferred
    function transferToken(
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