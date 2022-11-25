
//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

interface IAccount {
    function init(address admin, address beacon, bytes memory data) external;
}