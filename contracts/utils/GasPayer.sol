//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

contract GasPayer {
    event GasPaid(address to, uint256 payment);

    struct GasPayment {
        address payable receiver;
        address token;
        uint256 baseGas;
        uint256 price;
    }

    function _refundGas(
        GasPayment calldata gas,
        uint256 gasUsed
    ) internal returns (uint256 payment) {
        require(gas.receiver != address(0), "HEXLA014");
        gasUsed = gasUsed + gas.baseGas + 80000; // From 69369 to 76624 
        if (gas.token == address(0)) {
            payment = gasUsed * tx.gasprice;
            (bool success, ) = gas.receiver.call{value: payment}("");
            require(success, "HEXL020");
        } else {
            payment = gasUsed * tx.gasprice * gas.price / 1000000000;
            IERC20(gas.token).transfer(gas.receiver, payment);
        }
        emit GasPaid(gas.receiver, payment);
    }
}