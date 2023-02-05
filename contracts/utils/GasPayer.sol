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
        uint256 price;
    }

    function _refundGas(
        GasPayment calldata gas,
        uint256 gasUsed
    ) internal returns (uint256 payment) {
        require(gas.receiver != address(0), "HEXLA014");
        if (gas.token == address(0)) {
            gasUsed += 76620;
            uint256 price = gas.price == 0 ? tx.gasprice : gas.price;
            price = price > tx.gasprice ? tx.gasprice : price;
            payment = gasUsed * price;
            (bool success, ) = gas.receiver.call{value: payment}("");
            require(success, "HEXL020");
        } else {
            gasUsed += 69365;
            payment = gasUsed * gas.price;
            IERC20(gas.token).transfer(gas.receiver, payment);
        }
        emit GasPaid(gas.receiver, gasUsed);
    }
}