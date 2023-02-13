import { expect } from "chai";
import { ethers, deployments, artifacts, run, network } from "hardhat";

async function iface(contract: string) {
    const artifact = await artifacts.readArtifact(contract);
    return new ethers.utils.Interface(artifact.abi);
}

describe("Hexlink Redpacket", function() {
    beforeEach(async function() {
      await deployments.fixture(["HEXL"]);
    });

    it("deploy erc721", async function() {
        const { deployer } = await ethers.getNamedSigners();

        const tokenFactory = await run("token_factory", {});
        const erc721Iface = await iface("HexlinkErc721");
        const initData = erc721Iface.encodeFunctionData(
            "init",
            ["Hexlink NFT", "HEXL", "void", "1000", deployer.address]
        );
        const tx = await tokenFactory.connect(deployer).deployErc721(
            ethers.constants.HashZero,
            initData
        );
        const receipt = await tx.wait();
        const events = receipt.logs.filter(
            (log: any) => log.address === tokenFactory.address
        ).map((log: any) => tokenFactory.interface.parseLog(log));
        const event = events.find(
            (e: any) => e.name === "Deployed"
        );
        const deloyed = event.args.deployed;

        const contract = await ethers.getContractAt("HexlinkErc721", deloyed);
        expect(await contract.name()).to.eq("Hexlink NFT");
        expect(await contract.symbol()).to.eq("HEXL");
        expect(await contract.tokenURI(1)).to.eq("void");
        expect(await contract.maxSupply()).to.eq(1000);
        expect(await contract.owner()).to.eq(deployer.address);
        expect(await contract.validator()).to.eq(deployer.address);

        // mint
        const message = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256", "address", "address"],
                [network.config.chainId, deloyed, deployer.address]
            )
        );
        console.log(message);
        const signature = await deployer.signMessage(
            ethers.utils.arrayify(message)
        );
        const tx2 = await contract.connect(deployer).mint(
            deployer.address, signature
        );
        console.log(tx2);
    });
});
