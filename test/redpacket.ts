import { ethers, deployments, artifacts, run } from "hardhat";
import { Contract, BigNumber } from "ethers";

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

    it("Should deploy account and create red packet successfully", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();
        const packet = {
            balance: 10000,
            validator: validator.address,
            expiredAt: Math.floor( Date.now() / 1000 ) + 3600,
            split: 10,
            mode: 2,
        };
        const redPacket = await deployments.get("RedPacket");
        const gasStation = await deployments.get("GasStation");
        const hexlinkToken = await deployments.get("HexlinkToken");
    
        const packetSalt = ethers.constants.HashZero;
        const gasToken = ethers.constants.AddressZero;
        const gasPrice = await ethers.provider.getGasPrice();
        const gasSponsorAmount = gasPrice.mul(150000).mul(packet.split);
        const gasAmount = BigNumber.from(1000000);

        // deposit some token to tester
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(tester.address, 100000);
        // approve packet token
        const hexlink = await getHexlink();
        const accountAddr = await hexlink.addressOfName(sender);
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
        const redPacketIface = await iface("RedPacket");
        const op4 = {
            to: redPacket.address,
            value: 0,
            callData: redPacketIface.encodeFunctionData(
                "create", [hexlinkToken.address, packetSalt, packet]
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

        // build txData for execBatch
        const data = (await iface("AccountSimple")).encodeFunctionData(
            "execBatch",
            [[op1, op2, op3, op4, op5]]
        );

        // build txData for validateAndCall
        const gas = {
            token: gasToken,
            price: 0, // use tx.gasprice
            refund: 800000,
            refundReceiver: validator.address
        };
        const nonce = 0;
        const requestId = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["bytes", "tuple(address,uint256,uint256,address payable)", "uint256"],
                [data, [gas.token, gas.price, gas.refund, gas.refundReceiver], nonce]
            )
        );
        const signature = await tester.signMessage(
            ethers.utils.arrayify(requestId)
        );
        const txData = (await iface("AccountSimple")).encodeFunctionData(
            "validateAndCall",
            [data, gas, nonce, signature]
        );

        // deploy and call

        const hexlinkHelper = await getContract("HexlinkHelper");

        // build op to init account
        const accountIface = await iface("AccountSimple");
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
        await hexlinkHelper.connect(tester).deployAndCreateRedPacket(
            sender,
            initData,
            txData,
            authProof,
            hexlinkToken.address,
            packet.balance,
            gasToken,
            gasSponsorAmount,
            gasAmount,
            options
        );    
    });
});
  