//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract HexlinkErc721 is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable
{
    using ECDSA for bytes32;

    string public baseTokenURI;
    uint256 public maxSupply;
    uint256 public tokenId = 0;
    address public validator;

    function init(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        uint256 maxSupply_,
        address validator_
    ) external initializer {
        __ERC721_init(name_, symbol_);
        __Ownable_init();
        maxSupply = maxSupply_;
        validator = validator_;
        baseTokenURI = baseTokenURI_;
    }

    function mint(
        address recipient,
        bytes memory signature
    ) external returns (uint256) {
        tokenId += 1;
        require(tokenId <= maxSupply, "Exceeding max supply");
        _validate(recipient, signature);
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function _validate(address recipient, bytes memory signature) internal view {
        bytes32 message = keccak256(abi.encode(block.chainid, address(this), recipient));
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(validator == reqHash.recover(signature), "HEXLA004");
    }

    function tokenURI(uint256 /* tokenId */)
        public view override returns (string memory)
    {
        return baseTokenURI;
    }
}