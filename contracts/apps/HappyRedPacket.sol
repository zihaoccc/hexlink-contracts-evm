//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../Structs.sol";

contract HappyRedPacket {
    using ECDSA for bytes32;
    using Address for address;

    event Created(
        bytes32 indexed PacketId,
        RedPacket packet
    );
    event Claimed(
        bytes32 indexed PacketId,
        address claimer,
        uint amount
    );

    // user => PacketId => Packet as Packet
    mapping(bytes32 => RedPacket) internal packets_;
    mapping(bytes32 => mapping(address => uint256)) internal count_;
    address immutable public gasStation;

    constructor(address _gasStation) {
        gasStation = _gasStation;
    }

    function create(
        address token,
        bytes32 salt, // to identity a specific red Packet
        RedPacket memory packet
    ) external payable {
        bytes32 packetId = keccak256(abi.encode(msg.sender, token, salt));
        require(packets_[packetId].mode == 0, "RedPacket already exists");
        require(packet.mode == 1 || packet.mode == 2, "Invalid mode");
        require(packet.creator == msg.sender, "Invalid creator");
        if (token != address(0)) {
            IERC20(token).transferFrom(msg.sender, address(this), packet.balance);
        } else {
            require(msg.value >= packet.balance, "Insufficient balance");
        }
        packets_[packetId] = packet;
        emit Created(packetId, packet);
    }

    function getPacket(bytes32 id) external view returns(RedPacket memory) {
        return packets_[id];
    }

    function refund(address token, bytes32 salt) external {
        bytes32 packetId = keccak256(abi.encode(msg.sender, token, salt));
        _transfer(token, msg.sender, packets_[packetId].balance);
        packets_[packetId].balance = 0;
    }

    function claim(
        bytes32 packetId,
        address claimer,
        address refundReceiver,
        bytes calldata signature
    ) external {
        uint256 gasUsed = gasleft();
        RedPacket memory p = packets_[packetId];
        require(p.balance > 0 && p.split > 0, "Empty Packet");
        require(p.expiredAt == 0 || p.expiredAt > block.timestamp, "Packet Expired");

        // validate claimer
        require(count_[packetId][claimer] == 0, "Already claimed");
        bytes32 message = keccak256(
            abi.encode(packetId, claimer, refundReceiver)
        );
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(p.validator == reqHash.recover(signature), "Invalid signature");
        count_[packetId][claimer] += 1;

        // claim red Packet
        uint256 claimed = _claimd(claimer, p);
        packets_[packetId].balance = p.balance - claimed;
        packets_[packetId].split = p.split - 1;
        _transfer(p.token, claimer, claimed);
        emit Claimed(packetId, claimer, claimed);

        // pay gas with gas station
        if (p.enableGasStation) {
            uint256 payment = gasUsed - gasleft() + 60000;
            bytes memory data = abi.encodeWithSignature(
                "pay(address,address,uint256)", p.creator, refundReceiver, payment
            );
            (bool success,) = gasStation.call{gas: 60000}(data);
            require(success, "Failed to refund gas");
        }
    }

    function _claimd(address claimer, RedPacket memory p) internal view returns(uint256 claimed) {
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