//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RedPocket {
    using ECDSA for bytes32;
    using Address for address;

    event PocketCreated(bytes32 indexed pocketId, address creator, address token, bytes32 salt);
    event PocketClaimed(bytes32 indexed pocketId, address claimer, uint amount);

    struct Pocket {
        uint256 balance;
        address validator;
        uint64 expiredAt; // 0 means never expire
        uint24 numOfShares;
        uint8 mode; // 0: not_set, 1: fixed, 2: randomized
    }
    // user => pocketId => Pocket as pocket
    mapping(bytes32 => Pocket) internal pockets_;
    mapping(bytes32 => mapping(address => uint256)) internal count_;

    function create(
        address token,
        bytes32 salt, // to identity a specific red pocket
        uint256 amount,
        address validator,
        uint64 expiredAt,
        uint24 numOfShares,
        uint8 mode
    ) external payable {
        bytes32 pocketId = keccak256(abi.encode(msg.sender, token, salt));
        require(pockets_[pocketId].mode == 0, "Pocket already exists");
        require(mode == 1 || mode == 2, "Invalid mode");
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        } else {
            require(msg.value == amount, "Pocket value mismatch");
        }
        pockets_[pocketId] = Pocket(
            amount,
            validator,
            expiredAt,
            numOfShares,
            mode
        );
        emit PocketCreated(pocketId, msg.sender, token, salt);
    }

    function pocket(bytes32 id) external view returns(Pocket memory) {
        return pockets_[id];
    }

    function refund(address token, bytes32 salt) external {
        bytes32 pocketId = keccak256(abi.encode(msg.sender, token, salt));
        _transfer(token, msg.sender, pockets_[pocketId].balance);
        pockets_[pocketId].balance = 0;
    }

    function claim(
        address from,
        address token,
        bytes32 salt,
        address claimer,
        address gasStation, // 0 means do not use gas station
        address refundReceiver,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        bytes32 pocketId = keccak256(abi.encode(from, token, salt));
        Pocket memory p = pockets_[pocketId];
        require(p.balance > 0 && p.numOfShares > 0, "Empty pocket");
        require(p.expiredAt == 0 || p.expiredAt > block.timestamp, "Pocket Expired");

        // validate claimer
        require(count_[pocketId][claimer] == 0, "Already claimed");
        bytes32 message = keccak256(abi.encode(pocketId, claimer, gasStation, refundReceiver));
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(p.validator == reqHash.recover(signature), "Invalid signature");
        count_[pocketId][claimer] += 1;

        // claim red pocket
        uint256 claimed = _claimd(claimer, p);
        pockets_[pocketId].balance = p.balance - claimed;
        pockets_[pocketId].numOfShares = p.numOfShares - 1;
        _transfer(token, claimer, claimed);
        emit PocketClaimed(pocketId, claimer, claimed);

        // pay gas with gas station
        if (gasStation != address(0)) {
            uint256 payment = (gasUsed - gasleft() + 60000) * tx.gasprice;
            bytes memory data = abi.encodeWithSignature(
                "pay(address,address,uint256)", from, refundReceiver, payment
            );
            (bool success,) = gasStation.call{gas: 60000}(data);
            require(success, "Failed to pay gas");
        }
    }

    function _claimd(address claimer, Pocket memory p) internal view returns(uint256 claimed) {
        if (p.numOfShares == 1) {
            claimed = p.balance;
        } else if (p.mode == 1) { // fixed
            claimed = p.balance / p.numOfShares;
        } else if (p.mode == 2) { // randomized
            uint randomHash = uint(keccak256(
                abi.encode(claimer, block.difficulty, block.timestamp)
            ));
            uint maxPerShare = (p.balance / p.numOfShares) * 2;
            claimed = randomHash % maxPerShare;
        }
        if (claimed == 0) {
            claimed = 1;
        }
    }

    function _transfer(address token, address to, uint256 amount) internal {
        if (token == address(0)) {
            Address.sendValue(payable(to), amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }
}