//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";

interface IAccount is IERC1271 {
    function admin() external returns(address);
}
