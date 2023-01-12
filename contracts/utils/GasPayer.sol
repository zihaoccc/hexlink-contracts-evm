//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "hardhat/console.sol";

contract GasPayer {
    event GasPaid(address to, uint256 amount);

    struct GasPayment {
        address payable receiver;
        address token;
        uint256 base;
        uint256 price;
    }

    function _refundGas(
        GasPayment calldata gas,
        uint256 gasUsed
    ) internal returns (uint256 payment) {
        if (gas.receiver != address(0)) {
            gasUsed += gas.base;
            if (gas.token == address(0)) {
                uint256 price = gas.price == 0 ? tx.gasprice : gas.price;
                price = price > tx.gasprice ? tx.gasprice : price;
                payment = gasUsed * price;
                (bool success, ) = gas.receiver.call{value: payment}("");
                require(success, "HEXL020");
            } else {
                payment = gasUsed * gas.price;
                IERC20(gas.token).transfer(gas.receiver, payment);
            }
            emit GasPaid(gas.receiver, gasUsed);
        }
    }
}