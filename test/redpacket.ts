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

    it("erc20 as packet token and eth as gas token", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const redPacket = await deployments.get("HappyRedPacket");
        const hexlinkToken = await deployments.get("HexlinkToken");
    
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
            enableGasSponsorship: true,
        };
        // deposit some token to tester
        const token = await ethers.getContractAt("IERC20", hexlinkToken.address);
        await token.connect(deployer).transfer(tester.address, 100000);
        // approve packet token
        await token.connect(tester).approve(accountAddr, packet.balance);
        await token.connect(deployer).transfer(accountAddr, 1000000);
        
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
        const data = (await iface("AccountSimple")).encodeFunctionData(
            "execBatch",
            [[op1, op2, op3]]
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
        const accountIface = await iface("AccountSimple");
        const initData = accountIface.encodeFunctionData(
            "init", [tester.address]
        );
        const authProof = await run("build_deploy_auth_proof", {
            name: sender,
            identityType: "twitter.com",
            authType: "oauth",
            data: initData
        });

        const hexlinkHelper = await getContract("HexlinkHelper");
        const tx = await hexlinkHelper.connect(tester).deployAndCreateRedPacket(
            sender,
            initData,
            txData,
            authProof
        );
        const receipt = await tx.wait();
        const gasCost = receipt.gasUsed;
        console.log("real gas cost = "  + gasCost.toNumber());
    });
});
