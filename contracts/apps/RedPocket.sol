//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../utils/GasPayer.sol";

contract RedPocket is Ownable, GasPayer {
    using ECDSA for bytes32;
    using Address for address;

    event GasPayment(address indexed owner, bytes32 indexed request, uint256 payment);

    struct Pocket {
        uint256 balance;
        address validator;
        uint32 numOfShares;
        uint8 mode; // 0: not_set, 1: fixed, 2: randomized
    }
    // user => pocketId => Pocket as pocket
    mapping(address => mapping(bytes32 => Pocket)) private pockets_;
    // user => token => amount as gas deposit, address(0) as token for eth
    mapping(address => mapping(address => uint256)) private deposits_;

    constructor(address owner) {
        _transferOwnership(owner);
    }

    function deposit(address token) external payable {
        uint256 amount = msg.value;
        deposits_[msg.sender][address(0)] += amount;
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
            deposits_[msg.sender][token] += amount;
        }
    }

    function withdraw(address token, uint256 amount) external {
        require(deposits_[msg.sender][token] > amount, "Insufficient deposit to withdraw");
         deposits_[msg.sender][token] -= amount;
         _transfer(token, payable(msg.sender), amount);
    }

    function depositOf(address user, address token) external view returns(uint256) {
        return deposits_[user][token];
    }

    function createPocket(
        address token,
        bytes32 salt, // to identity a specific red pocket
        uint256 amount,
        address validator,
        uint32 numOfShares,
        uint8 mode
    ) external {
        bytes32 pocketId = keccak256(abi.encode(token, salt));
        require(pockets_[msg.sender][pocketId].mode == 0, "Pocket already exists");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        pockets_[msg.sender][pocketId] = Pocket(
            amount,
            validator,
            numOfShares,
            mode
        );
    }

    function redPocket(address owner, bytes32 id) external view returns(Pocket memory) {
        return pockets_[owner][id];
    }

    function terminatePocket(address token, bytes32 salt) external {
        bytes32 pocketId = keccak256(abi.encode(token, salt));
        Pocket memory pocket = pockets_[msg.sender][pocketId];
        _transfer(token, payable(msg.sender), pocket.balance);
        pockets_[msg.sender][pocketId].balance = 0;
    }

    function claimPocket(
        address from,
        address to,
        address token,
        bytes32 salt,
        address payable paymaster,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        bytes32 pocketId = keccak256(abi.encode(token, salt));
        Pocket memory pocket = pockets_[from][pocketId];
        require(pocket.balance > 0 && pocket.numOfShares > 0, "Empty pocket");

        // validate signature
        bytes32 message = keccak256(
            abi.encode(to, paymaster, "VALID_TO_CLAIM")
        );
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(pocket.validator == reqHash.recover(signature), "invalid signature");

        // claim red pocket
        uint256 claimed = _claimd(to, pocket);
        pockets_[from][pocketId].balance = pocket.balance - claimed;
        pockets_[from][pocketId].numOfShares = pocket.numOfShares - 1;
        _transferToken(token, to, claimed);

        // pay gas with deposit
        uint256 payment = (gasUsed - gasleft() + 60000) * tx.gasprice;
        _deposits[from][address(0)] -= payment;
        Address.sendValue(paymaster, payment);
        emit GasPayment(from, pocketId, payment);
    }

    function _claimd(address beneficiary, Pocket memory pocket) internal view returns(uint256 claimed) {
        require(pocket.numOfShares > 0, "No shares left");
        if (pocket.numOfShares == 1) {
            claimed = pocket.balance;
        } else if (pocket.mode == 1) { // fixed
            claimed = pocket.balance / pocket.numOfShares;
        } else if (pocket.mode == 2) { // randomized
            uint randomHash = uint(keccak256(
                abi.encode(beneficiary, block.difficulty, block.timestamp)
            ));
            uint maxPerShare = pocket.balance / 3;
            claimed = randomHash % maxPerShare;
        }
    }
}