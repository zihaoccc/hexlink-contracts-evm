//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./AccountBase.sol";

contract AccountSimple is AccountBase {
    using Address for address;

    struct GasObject {
        address token;
        uint256 price;
        uint256 refund;
        address payable refundReceiver;
    }

    event GasPayment(bytes32 indexed request, uint256 payment);
    uint256 private nonce_;
    
    function init(address owner) external {
        require(_owner() == address(0) && owner != address(0), "HEXL015");
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
        bytes32 requestId = keccak256(abi.encode(txData, gas, nonce_));
        require(nonce_++ == _nonce, "HEXLA008");
        _validateSignature(requestId, signature);
        (bool success,) = address(this).call(txData);
        require(success, "HEXLA009");
        if (gas.refund > 0) {
            uint256 payment = _handleGasPayment(
                gas.refund,
                gas.token,
                gas.price,
                gas.refundReceiver
            );
            emit GasPayment(requestId, payment);
        }
    }

    function _validateCaller() internal view override {
        require(msg.sender == owner() || msg.sender == address(this), "HEXLA011");
    }

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
            IERC20(token).transfer(receiver, amount);
        }
    }
}