import { ethers, deployments, artifacts, run } from "hardhat";
import { Contract, BigNumber } from "ethers";
import { HexlinkToken__factory } from "../typechain";

const namehash = function(name: string) : string {
    return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
}
const senderName = "mailto:sender@gmail.com";
const sender = namehash(senderName);

async function iface(contract: string) {
    const artifact = await artifacts.readArtifact(contract);
    return new ethers.utils.Interface(artifact.abi);
}

async function getContract(name: string) : Promise<Contract> {
    const deployment = await deployments.get(name);
    return await ethers.getContractAt(name, deployment.address);
}

async function getHexlink() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkProxy");
    return await ethers.getContractAt("Hexlink", deployment.address);
}

describe("Hexlink Account", function() {
    beforeEach(async function() {
      await deployments.fixture(["HEXL"]);
    });

    it("erc20 as packet token and eth as gas token", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const redPacket = await deployments.get("HappyRedPacket");
        const gasStation = await deployments.get("GasStation");
        const hexlinkToken = await deployments.get("HexlinkToken");
    
        const packetSalt = ethers.constants.HashZero;
        const gasToken = ethers.constants.AddressZero;
        const gasPrice = await ethers.provider.getGasPrice();
        const gasAmount = BigNumber.from(1000000);

        const hexlink = await getHexlink();
        const accountAddr = await hexlink.addressOfName(sender);

        const packet = {
            token: hexlinkToken.address,
            salt: ethers.constants.HashZero,
            balance: 10000,
            validator: validator.address,
            expiredAt: Math.floor( Date.now() / 1000 ) + 3600,
            split: 10,
            mode: 2,
            gasStation: gasStation.address,
        };
        const gasSponsorAmount = gasPrice.mul(150000).mul(packet.split);

        // deposit some token to tester
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(tester.address, 100000);
        // approve packet token
        await token.connect(tester).approve(accountAddr, packet.balance);
    
        // build op to deposit eth to gas station
        const gasStationIface = await iface("GasStation");
        const op1 = {
            to: gasStation.address,
            value: gasAmount,
            callData: gasStationIface.encodeFunctionData(
                "deposit", []
            ),
            callGasLimit: 0 // no limit
        };

        // build op to transfer packet token from tester to account
        const op2 = {
            to: hexlinkToken.address,
            value: 0,
            callData: token.interface.encodeFunctionData(
                "transferFrom", [tester.address, accountAddr, packet.balance]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to approve red packet for packet token
        const op3 = {
            to: hexlinkToken.address,
            value: 0,
            callData: token.interface.encodeFunctionData(
                "approve", [redPacket.address, packet.balance]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to create red packet
        const redPacketIface = await iface("HappyRedPacket");
        const op4 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [packet]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to whitelist red packet for gas station
        const op5 = {
            to: gasStation.address,
            value: 0,
            callData: gasStationIface.encodeFunctionData(
                "increaseAllowance", [redPacket.address, gasSponsorAmount]
            ),
            callGasLimit: 0 // no limit
        };

        // build op to refund gas for tx sender
        const accountIface = await iface("AccountSimple");
        const op6 = {
            to: accountAddr,
            value: 0,
            callData: accountIface.encodeFunctionData(
                "refundGas", [
                    validator.address,
                    ethers.constants.AddressZero,
                    gasAmount,
                    0,
                ]
            ),
            callGasLimit: 0 // no limit
        };

        // build txData for execBatch
        const data = (await iface("AccountSimple")).encodeFunctionData(
            "execBatch",
            [[op1, op2, op3, op4, op5, op6]]
        );

        // build txData for validateAndCall
        const nonce = 0;
        const requestId = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes", "uint256"],
                [data, nonce]
            )
        );
        const signature = await tester.signMessage(
            ethers.utils.arrayify(requestId)
        );
        const txData = (await iface("AccountSimple")).encodeFunctionData(
            "validateAndCall",
            [data, nonce, signature]
        );

        // build op to init account
        const initData = accountIface.encodeFunctionData(
            "init", [tester.address]
        );
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: "4", // twitter
            authType: "2", // oauth
            data: initData
        });

        const options = { value: gasSponsorAmount.add(gasAmount) };
        const hexlinkHelper = await getContract("HexlinkHelper");
        await hexlinkHelper.connect(tester).deployAndCreateRedPacket(
            sender,
            initData,
            txData,
            authProof,
            options
        );    
    });
});
  