import { expect } from "chai";
import { ethers, deployments, artifacts, run, network } from "hardhat";
import { Contract } from "ethers";

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
    const deployment = await deployments.get("Hexlink");
    return await ethers.getContractAt("HexlinkUpgradeable", deployment.address);
}

async function getRedPacket() : Promise<Contract> {
    const deployment = await deployments.get("HappyRedPacket");
    return await ethers.getContractAt("HappyRedPacketImpl", deployment.address);
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

    it("erc20 as packet token and eth as gas token with deploy", async function() {
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
        await token.connect(tester).approve(accountAddr, packet.balance + 100);

        // build op to transfer packet token from tester to account
        const op0 = {
            to: hexlinkToken.address,
            value: 0,
            callData: token.interface.encodeFunctionData(
                "transferFrom", [tester.address, accountAddr, packet.balance + 100]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to deposit gas sponsorship
        const accountIface = await iface("AccountSimple");
        const id = genRedPacketId(redPacket.address, accountAddr, packet);
        const op1 = {
            to: accountAddr,
            value: 0,
            callData: accountIface.encodeFunctionData(
                "deposit", [id, tester.address, hexlinkToken.address, 100]
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
        const redPacketIface = await iface("HappyRedPacketImpl");
        const op3 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const opsData = accountIface.encodeFunctionData(
            "execBatch",
            [[op0, op1, op2, op3]]
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

        const data = hexlink.interface.encodeFunctionData(
            "deploy",
            [sender, initData, authProof],
        );

        const value = ethers.utils.parseEther("1.0");
        const tx = await hexlink.connect(tester).process([{
            to: accountAddr,
            value,
            callData: [],
            callGasLimit: 0
        }, {
            to: hexlink.address,
            value: 0,
            callData: data,
            callGasLimit: 0
        }], {value});
        const receipt = await tx.wait();
        const gasCost = receipt.gasUsed;
        console.log("real gas cost = "  + gasCost.toNumber());

        expect(
            await ethers.provider.getBalance(accountAddr)
        ).to.eq(value);

        const hash = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes32", "address"],
                [id, tester.address]
            )
        );
        const signature = await validator.signMessage(
            ethers.utils.arrayify(hash)
        );
        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(0);
        const tx2 = await redPacket.connect(deployer).claim({
            creator: accountAddr,
            packet,
            claimer: tester.address,
            signature
        });
        await tx2.wait();
        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(1);
    });

    it("erc20 as packet token and eth as gas token", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const hexlinkToken = await deployments.get("HexlinkToken");
        const hexlink = await getHexlink();
        const redPacket = await getRedPacket();
        const accountAddr = await hexlink.addressOfName(sender);

        // deploy
        const accountIface = await iface("AccountSimple");
        const initData = accountIface.encodeFunctionData("init", [
            tester.address, []
        ]);
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: "twitter.com",
            authType: "oauth",
            data: initData
        });
        await hexlink.connect(tester).deploy(sender, initData, authProof);
        const account = await ethers.getContractAt("AccountSimple", accountAddr);

        // create redpacket
        const packet = {
            token: hexlinkToken.address,
            salt: ethers.constants.HashZero,
            balance: 10000,
            validator: validator.address,
            split: 10,
            mode: 2
        };
        // deposit some token to account str
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(accountAddr, 1000000);
        await tester.sendTransaction({to: accountAddr, value: ethers.utils.parseEther("1.0")});

        // build op to deposit gas sponsorship
        const id = genRedPacketId(redPacket.address, accountAddr, packet);
        const op1 = {
            to: accountAddr,
            value: 0,
            callData: accountIface.encodeFunctionData(
                "deposit", [id, tester.address, ethers.constants.AddressZero, 100 * 10]
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
        const redPacketIface = await iface("HappyRedPacketImpl");
        const op3 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const opsData = accountIface.encodeFunctionData(
            "execBatch",
            [[op1, op2, op3]]
        );
        const gas = {
            receiver: tester.address,
            token: ethers.constants.AddressZero,
            baseGas: 0,
            price: 0,
        };
        const message = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes", "uint256", "tuple(address, address, uint256, uint256)"],
                [opsData, 0, [gas.receiver, gas.token, gas.baseGas, gas.price]]
            )
        );
        const signature = await tester.signMessage(ethers.utils.arrayify(message));
        const nonce = await account.nonce();
        const tx = await account.connect(deployer).validateAndCallWithGasRefund(
            opsData, nonce, signature, gas
        );
        const receipt = await tx.wait();
        const event = receipt.events.find((e: any) => e.event === "GasPaid");
        console.log("gas payment = "  + event.args.payment.toString());
        console.log("real gas price = "  + receipt.effectiveGasPrice.toNumber());
        console.log("real gas cost = "  + receipt.gasUsed.toNumber());
        console.log("expected payment = "  + receipt.gasUsed.mul(receipt.effectiveGasPrice).toString());

        const hash = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes32", "address"],
                [id, tester.address]
            )
        );
        const sig = await validator.signMessage(
            ethers.utils.arrayify(hash)
        );
        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(0);
        const tx2 = await redPacket.connect(deployer).claim({
            creator: accountAddr,
            packet,
            claimer: tester.address,
            signature: sig
        });
        await tx2.wait();
        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(1);
    });

    it("erc20 as gas token", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const hexlinkToken = await deployments.get("HexlinkToken");
        const hexlink = await getHexlink();
        const redPacket = await getRedPacket();
        const accountAddr = await hexlink.addressOfName(sender);

        // deploy
        const accountIface = await iface("AccountSimple");
        const initData = accountIface.encodeFunctionData("init", [
            tester.address, []
        ]);
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: "twitter.com",
            authType: "oauth",
            data: initData
        });
        await hexlink.connect(tester).deploy(sender, initData, authProof);
        const account = await ethers.getContractAt("AccountSimple", accountAddr);

        // create redpacket
        const packet = {
            token: hexlinkToken.address,
            salt: ethers.constants.HashZero,
            balance: 10000,
            validator: validator.address,
            split: 10,
            mode: 2
        };
        // deposit some token to account str
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(accountAddr, "1000000000000000000");
        await tester.sendTransaction({to: accountAddr, value: ethers.utils.parseEther("1.0")});

        // build op to deposit gas sponsorship
        const id = genRedPacketId(redPacket.address, accountAddr, packet);
        const op1 = {
            to: accountAddr,
            value: 0,
            callData: accountIface.encodeFunctionData(
                "deposit", [id, tester.address, ethers.constants.AddressZero, 100 * 10]
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
        const redPacketIface = await iface("HappyRedPacketImpl");
        const op3 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const opsData = accountIface.encodeFunctionData(
            "execBatch",
            [[op1, op2, op3]]
        );
        const gas = {
            receiver: tester.address,
            token: hexlinkToken.address,
            baseGas: "0",
            price: "1000000000000", // 1 hexl = 10^18 = 0.001 ETH = 10^15 wei => 1gwei = 10^9 wei = 10^12 hexl
        };
        const message = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes", "uint256", "tuple(address, address, uint256, uint256)"],
                [opsData, 0, [gas.receiver, gas.token, gas.baseGas, gas.price]]
            )
        );
        const signature = await tester.signMessage(ethers.utils.arrayify(message));
        const nonce = await account.nonce();
        const tx = await account.connect(deployer).validateAndCallWithGasRefund(
            opsData, nonce, signature, gas
        );
        const receipt = await tx.wait();
        const event = receipt.events.find((e: any) => e.event === "GasPaid");
        console.log("gas payment = "  + event.args.payment.toString());
        console.log("real gas price = "  + receipt.effectiveGasPrice.toNumber());
        console.log("real gas cost = "  + receipt.gasUsed.toNumber());
        console.log("expected payment = "  + receipt.gasUsed.mul(receipt.effectiveGasPrice).mul(1000).toString());

        const hash = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes32", "address"],
                [id, tester.address]
            )
        );
        const sig = await validator.signMessage(
            ethers.utils.arrayify(hash)
        );

        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(0);
        const tx2 = await redPacket.connect(deployer).claim({
            creator: accountAddr,
            packet,
            claimer: tester.address,
            signature: sig
        });
        await tx2.wait();
        expect(await redPacket.getClaimedCount(id, tester.address)).to.eq(1);
    });
});
