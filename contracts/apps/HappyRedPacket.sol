//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract HappyRedPacket {
    using ECDSA for bytes32;
    using Address for address;

    event Created(
        bytes32 indexed PacketId,
        address creator,
        RedPacketData packet
    );
    event Claimed(
        bytes32 indexed PacketId,
        address claimer,
        uint amount
    );

    struct RedPacketData {
        address token;
        bytes32 salt;
        uint256 balance;
        address validator;
        uint32 split;
        uint8 mode; // 0: not_set, 1: fixed, 2: randomized
    }

    struct RedPacket {
        uint256 createdAt;
        uint256 balance;
        uint32 split;
    }
    // user => PacketId => Packet as Packet
    mapping(bytes32 => RedPacket) internal packets_;
    mapping(bytes32 => mapping(address => uint256)) internal count_;

    function create(RedPacketData memory pd) external payable {
        require(pd.mode == 1 || pd.mode == 2, "Invalid mode");
        bytes32 packetId = _packetId(msg.sender, pd.token, pd.salt);
        require(packets_[packetId].createdAt == 0, "Packet already created");
        if (pd.token != address(0)) {
            IERC20(pd.token).transferFrom(msg.sender, address(this), pd.balance);
        } else {
            require(msg.value >= pd.balance, "Insufficient balance");
        }
        packets_[packetId].balance += pd.balance;
        packets_[packetId].split += pd.split;
        packets_[packetId].createdAt = block.timestamp;
        emit Created(packetId, msg.sender, pd);
    }

    function getPacket(bytes32 id) external view returns(RedPacket memory) {
        return packets_[id];
    }

    function refund(address token, bytes32 salt) external {
        bytes32 packetId = _packetId(msg.sender, token, salt);
        // packet locked for one day before withdraw
        require(block.timestamp - packets_[packetId].createdAt > 86400, "Packet locked");
        _transfer(token, msg.sender, packets_[packetId].balance);
        packets_[packetId].balance = 0;
    }

    function claim(
        address creator,
        RedPacketData memory pd,
        address claimer,
        address refundReceiver,
        bytes calldata signature
    ) external {
        bytes32 packetId = _packetId(creator, pd.token, pd.salt);

        // validate claimer
        require(count_[packetId][claimer] == 0, "Already claimed");
        bytes32 message = keccak256(
            abi.encode(packetId, claimer, refundReceiver)
        );
        bytes32 reqHash = message.toEthSignedMessageHash();
        require(pd.validator == reqHash.recover(signature), "Invalid signature");
        count_[packetId][claimer] += 1;

        // claim red Packet
        RedPacket memory p = packets_[packetId];
        uint256 claimed = _claimd(claimer, pd.mode, p);
        packets_[packetId].balance = p.balance - claimed;
        packets_[packetId].split = p.split - 1;
        _transfer(pd.token, claimer, claimed);
        emit Claimed(packetId, claimer, claimed);
    }

    function _claimd(
        address claimer,
        uint8 mode,
        RedPacket memory p
    ) internal view returns(uint256 claimed) {
        require(p.balance > 0 && p.split > 0, "Empty Packet");
        if (p.split == 1) {
            claimed = p.balance;
        } else if (mode == 1) { // equally shared
            claimed = p.balance / p.split;
        } else if (mode == 2) { // randomized
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

    function _packetId(
        address creator,
        address token,
        bytes32 salt
    ) internal view returns (bytes32) {
        return keccak256(
          abi.encode(block.chainid, address(this), creator, token, salt)
        );
    }
}
