import { expect } from "chai";
import { ethers, deployments, artifacts, run } from "hardhat";
import { request } from "http";
import { HexlinkToken } from "../typechain";

const namehash = function(name: string) : string {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
}
const senderName = "mailto:sender@gmail.com";
const sender = namehash(senderName);

async function accountInitData(owner: string) : Promise<string> {
    const artifact = await artifacts.readArtifact("AccountSimple");
    const iface = new ethers.utils.Interface(artifact.abi);
    return iface.encodeFunctionData("init", [owner]);
}

async function iface(contract: string) {
    const artifact = await artifacts.readArtifact(contract);
    return new ethers.utils.Interface(artifact.abi);
}

async function getHexlink() {
    const hexlink = await deployments.get("HexlinkProxy");
    return await ethers.getContractAt("IHexlink", hexlink.address);
}


// This task is to setup redpacket for a new experience user
// Before running the task, the user will have to
// 1. approve packet token from owner to hexlink account
// 2. approve gas token from owner to hexlink account
//
// This will do following operations in one tx:
// 1. deploy hexlink account for user
// 2. deposit token/coin from owner (e.g. metamask) to hexlink account
// 3. approve hexlink account to red packet token contract
// 4. deposit hexlink account to gas token contract
// 5. approve hexlink account to gas token contract
// 6. approve red pocket contract to gas station contract
// 7. create red packet
describe("Hexlink Account", function() {
    beforeEach(async function() {
      await deployments.fixture(["HEXL"]);
    });

    it("Should deploy account and create red packet successfully", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();
        const packet = {
            balance: 10000,
            validator: validator.address,
            expiredAt: Math.floor( Date.now() / 1000 ) + 3600,
            split: 10,
            mode: 2,
        }
        const redPacket = await deployments.get("RedPacket");
        const gasStation = await deployments.get("GasStation");
        const hexlinkToken = await deployments.get("HexlinkToken");
    
        const packetSalt = ethers.constants.HashZero;
        const gasToken = ethers.constants.AddressZero;
        const gasAmount = 600000;
        const erc20Iface = await iface("IERC20");

        // deposit some token to admin
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(tester.address, 100000);

        // build op to init account
        const hexlinkIface = await iface("Hexlink");
        const op1 = {
            to: gasStation.address,
            value: gasAmount,
            callData: hexlinkIface.encodeFunctionData(
                "init", [tester.address]
            ),
            callGasLimit: 0 // no limit
        };
    
        // build op to deposit gas token
        const gasStationIface = await iface("GasStation");
        const op2 = {
            to: gasStation.address,
            value: gasAmount,
            callData: gasStationIface.encodeFunctionData(
                "deposit", []
            ),
            callGasLimit: 0 // no limit
        };

        // build op to approve packet token
        const op3 = {
            to: hexlinkToken.address,
            value: 0,
            callData: erc20Iface.encodeFunctionData(
                "approve", [redPacket.address, packet.balance]
            ),
            callGasLimit: 0 // no limit
        };
    
        // build op to create red packet
        const redPacketIface = await iface("RedPacket");
        const op4 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [hexlinkToken.address, packetSalt, packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const data = (await iface("AccountSimple")).encodeFunctionData(
            "execBatch",
            [op1, op2, op3, op4]
        );

        // build txData for validateAndCall
        const gas = {
            token: gasToken,
            price: 0, // use tx.gasprice
            core: 600000,
            base: 200000, // 40000 gas refund + 150000 deployment cost
            refundReceiver: validator.address
        };
        const requestId = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes", "tuple(address,uint256,uint256,uint256,address)", "uint256"],
                [data, [gas.token, gas.price, gas.core, gas.base, gas.refundReceiver], 0]
            )
        );
        const signature = await tester.signMessage(
            ethers.utils.arrayify(requestId)
        );
        const txData = (await iface("AccountSimple")).encodeFunctionData(
            "validateAndCall",
            [data, gas, 0, signature]
        );

        // deploy and call
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: 4, // twitter
            authType: 2, // oauth
            data: txData
        });
        const hexlink = await getHexlink();
        await hexlink.deploy(sender, txData, authProof);    
    });
});
  