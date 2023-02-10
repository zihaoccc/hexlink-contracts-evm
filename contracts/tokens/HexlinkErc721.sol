//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "../utils/IERC173.sol";

contract HexlinkErc721 is
    Initializable,
    OwnableUpgradeable,
    ERC721Upgradeable
{
    using ECDSA for bytes32;

    event Deployed(address indexed creator, address newContract);

    string public baseTokenURI;
    uint256 public tokenId = 0;
    address public validator;

    function init(
        string memory name_,
        string memory symbol_,
        string memory baseTokenURI_,
        address validator_
    ) external initializer {
        __ERC721_init(name_, symbol_);
        __Ownable_init();
        validator = validator_;
        baseTokenURI = baseTokenURI_;
    }

    function create(bytes32 salt, bytes memory initData) external {
        address account = Clones.cloneDeterministic(address(this), salt);
        (bool success, bytes memory data) = account.call(initData);
        Address.verifyCallResult(success, data, "Failed to init contract");
        IERC173(account).transferOwnership(msg.sender);
        emit Deployed(msg.sender, account);
    }

    function mint(
        address recipient,
        bytes memory signature
    ) external returns (uint256) {
        tokenId += 1;
        _validate(recipient, signature);
        _safeMint(recipient, tokenId);
        return tokenId;
    }

    function setValidator(address _validator) external onlyOwner {
        validator = _validator;
    }

    function _validate(address recipient, bytes memory signature) internal view {
        bytes32 message = keccak256(abi.encode("address", recipient));
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(validator == reqHash.recover(signature), "HEXLA004");
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
