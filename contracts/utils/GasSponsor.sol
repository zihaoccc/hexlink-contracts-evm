//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

abstract contract GasSponsor {
    event GasSponsorship(address indexed receiver, uint256 payment);

    function _sponsorGas(uint256 payment, address receiver) internal {
        (bool success, ) = receiver.call{value: payment}("");
        require(success, "HEXL020");
        emit GasSponsorship(receiver, payment);
    }
}