//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RedPacket {
    using ECDSA for bytes32;
    using Address for address;

    event PacketCreated(
        bytes32 indexed PacketId,
        address creator,
        address token,
        bytes32 salt,
        uint256 amount,
        uint32 split
    );
    event PacketClaimed(
        bytes32 indexed PacketId,
        address claimer,
        uint amount
    );

    struct Packet {
        uint256 balance;
        address validator;
        uint64 expiredAt; // 0 means never expire
        uint24 split;
        uint8 mode; // 0: not_set, 1: fixed, 2: randomized
    }
    // user => PacketId => Packet as Packet
    mapping(bytes32 => Packet) internal packets_;
    mapping(bytes32 => mapping(address => uint256)) internal count_;

    function create(
        address token,
        bytes32 salt, // to identity a specific red Packet
        uint256 amount,
        address validator,
        uint64 expiredAt,
        uint24 split,
        uint8 mode
    ) external payable {
        bytes32 PacketId = keccak256(abi.encode(msg.sender, token, salt));
        require(packets_[PacketId].mode == 0, "Packet already exists");
        require(mode == 1 || mode == 2, "Invalid mode");
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        } else {
            require(msg.value == amount, "Packet value mismatch");
        }
        packets_[PacketId] = Packet(amount, validator, expiredAt, split, mode);
        emit PacketCreated(PacketId, msg.sender, token, salt, amount, split);
    }

    function packet(bytes32 id) external view returns(Packet memory) {
        return packets_[id];
    }

    function refund(address token, bytes32 salt) external {
        bytes32 PacketId = keccak256(abi.encode(msg.sender, token, salt));
        _transfer(token, msg.sender, packets_[PacketId].balance);
        packets_[PacketId].balance = 0;
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
        bytes32 PacketId = keccak256(abi.encode(from, token, salt));
        Packet memory p = packets_[PacketId];
        require(p.balance > 0 && p.split > 0, "Empty Packet");
        require(p.expiredAt == 0 || p.expiredAt > block.timestamp, "Packet Expired");

        // validate claimer
        require(count_[PacketId][claimer] == 0, "Already claimed");
        bytes32 message = keccak256(
            abi.encode(PacketId, claimer, gasStation, refundReceiver)
        );
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(p.validator == reqHash.recover(signature), "Invalid signature");
        count_[PacketId][claimer] += 1;

        // claim red Packet
        uint256 claimed = _claimd(claimer, p);
        packets_[PacketId].balance = p.balance - claimed;
        packets_[PacketId].split = p.split - 1;
        _transfer(token, claimer, claimed);
        emit PacketClaimed(PacketId, claimer, claimed);

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

    function _claimd(address claimer, Packet memory p) internal view returns(uint256 claimed) {
        if (p.split == 1) {
            claimed = p.balance;
        } else if (p.mode == 1) { // fixed
            claimed = p.balance / p.split;
        } else if (p.mode == 2) { // randomized
            uint randomHash = uint(keccak256(
                abi.encode(claimer, block.difficulty, block.timestamp)
            ));
            uint maxPerShare = (p.balance / p.split) * 2;
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