import { expect } from "chai";
import { ethers, deployments, artifacts, run, network } from "hardhat";
import { Contract } from "ethers";
import { AbiCoder } from "ethers/lib/utils";

const namehash = function(name: string) : string {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
}
const senderName = "mailto:sender@gmail.com";
const sender = namehash(senderName);

async function iface(contract: string) {
    const artifact = await artifacts.readArtifact(contract);
    return new ethers.utils.Interface(artifact.abi);
}

async function getHexlink() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkProxy");
    return await ethers.getContractAt("Hexlink", deployment.address);
}

async function getRedPacket() : Promise<Contract> {
    const deployment = await deployments.get("HappyRedPacketProxy");
    return await ethers.getContractAt("HappyRedPacket", deployment.address);
}

function genRedPacketId(contract: string, creator: string, packet: any) : string {
    const redPacketType = "tuple(address,bytes32,uint256,address,uint32,uint8)";
    return ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "address", redPacketType],
            [
                network.config.chainId,
                contract,
                creator,
                [
                    packet.token,
                    packet.salt,
                    packet.balance,
                    packet.validator,
                    packet.split,
                    packet.mode
                ]
            ]
        )
    );
}

describe("Hexlink Redpacket", function() {
    beforeEach(async function() {
      await deployments.fixture(["HEXL"]);
    });

    it("erc20 as packet token and eth as gas token", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const hexlinkToken = await deployments.get("HexlinkToken");
        const hexlink = await getHexlink();
        const redPacket = await getRedPacket();
        const accountAddr = await hexlink.addressOfName(sender);

        const packet = {
            token: hexlinkToken.address,
            salt: ethers.constants.HashZero,
            balance: 10000,
            validator: validator.address,
            split: 10,
            mode: 2
        };
        // deposit some token to tester
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(tester.address, 1000000);
        await token.connect(tester).approve(accountAddr, packet.balance);

        // build op to transfer packet token from tester to account
        const op1 = {
            to: hexlinkToken.address,
            value: 0,
            callData: token.interface.encodeFunctionData(
                "transferFrom", [tester.address, accountAddr, packet.balance]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to approve red packet for packet token
        const op2 = {
            to: hexlinkToken.address,
            value: 0,
            callData: token.interface.encodeFunctionData(
                "approve", [redPacket.address, packet.balance]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to create red packet
        const redPacketIface = await iface("HappyRedPacket");
        const op3 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const accountIface = await iface("AccountSimple");
        const opsData = accountIface.encodeFunctionData(
            "execBatch",
            [[op1, op2, op3]]
        );
        const initData = accountIface.encodeFunctionData("init", [
            tester.address, opsData
        ]);

        // build op to init account
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: "twitter.com",
            authType: "oauth",
            data: initData
        });

        const value = ethers.utils.parseEther("1.0");
        const tx = await hexlink.connect(tester).deploy(
            sender,
            initData,
            authProof,
            {value}
        );
        const receipt = await tx.wait();
        const gasCost = receipt.gasUsed;
        console.log("real gas cost = "  + gasCost.toNumber());

        expect(
            await ethers.provider.getBalance(accountAddr)
        ).to.eq(value);

        const id = genRedPacketId(redPacket.address, accountAddr, packet)
        const info = await redPacket.getPacket(id);
        const hash = ethers.utils.keccak256(    
            ethers.utils.defaultAbiCoder.encode(
                ["bytes32", "address"],
                [id, tester.address]
            )
        );
        const signature = validator.signMessage(
            ethers.utils.arrayify(hash)
        );
        const tx2 = await redPacket.connect(deployer).claim(
            accountAddr, packet, tester.address, signature
        );
        const receipt2 = await tx2.wait();
        console.log(receipt2.events);
    });
});
