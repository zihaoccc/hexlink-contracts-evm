//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../utils/ISwap.sol";

contract GasPayer {
    event GasPaid(uint256 payment);

    struct GasPayment {
        address swapper;
        address token;
        address receiver;
        uint256 baseGas;
    }

    function _refundGas(
        GasPayment calldata gas,
        uint256 gasUsed
    ) internal returns (uint256 payment) {
        if (gas.token != address(0)) {
            gasUsed = gasUsed + gas.baseGas + 80000; 
            payment = gasUsed * tx.gasprice;
            uint256 price = ISwap(gas.swapper).priceOf(gas.token);
            uint256 amountIn = payment * price / 1000000000000000000 + 1;
            IERC20(gas.token).approve(gas.swapper, amountIn);
            ISwap(gas.swapper).swapExactOutputAndCall(gas.token, payment, gas.receiver, "");
        } else {
            gasUsed = gasUsed + gas.baseGas + 50000; // From 69369 to 76624 
            payment = gasUsed * tx.gasprice;
            Address.sendValue(payable(gas.receiver), payment);
        }
        emit GasPaid(payment);
    }
}