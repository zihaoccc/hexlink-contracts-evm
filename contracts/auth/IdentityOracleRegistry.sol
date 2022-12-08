// SPDX-License-Identifier: MIT
// Hexlink Contracts

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IIdentityOracleRegistry.sol";

contract IdentityOracleRegsitry is IIdentityOracleRegistry, Ownable {
    using Address for address;

    event SetOracle(
        uint128 indexed identityType,
        uint128 indexed authType,
        address oracle
    );

    event SetOracles(
        uint128[] indexed identityTypes,
        uint128[] indexed authTypes,
        address[] oracles
    );

    mapping(uint256 => address) private oracles_;

    constructor(
        address owner,
        uint128[] memory identityTypes,
        uint128[] memory authTypes,
        address[] memory oracles
    ) {
        _transferOwnership(owner);
        setOracles(identityTypes, authTypes, oracles);
    }

    function oracle(
        uint128 identityType,
        uint128 authType
    ) public view override returns (address) {
        return oracles_[identityType << 128 + authType];
    }

    function setOracle(
        uint128 identityType,
        uint128 authType,
        address _oracle
    ) external onlyOwner {
        _setOracle(identityType, authType, _oracle);
        emit SetOracle(identityType, authType, _oracle);
    }

    function setOracles(
        uint128[] memory identityTypes,
        uint128[] memory authTypes,
        address[] memory oracles
    ) public onlyOwner {
        require(identityTypes.length == oracles.length
            && authTypes.length == oracles.length, "HEXL001");
        for (uint256 i = 0; i < oracles.length; i++) {
            _setOracle(identityTypes[i], authTypes[i], oracles[i]);
        }
        emit SetOracles(identityTypes, authTypes, oracles);
    }

    function _setOracle(
        uint128 identityType,
        uint128 authType,
        address _oracle
    ) internal {
        require(identityType != 0 && _oracle != address(0), "HEXL002");
        require(_oracle.isContract(), "HEXL013");
        oracles_[identityType << 128 + authType] = _oracle;
    }
}