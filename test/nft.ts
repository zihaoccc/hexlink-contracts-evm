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
        const { deployer, validator } = await ethers.getNamedSigners();

        const tokenFactory = await run("token_factory", {});
        const erc721Iface = await iface("HexlinkErc721Impl");
        const initData = erc721Iface.encodeFunctionData(
            "init",
            ["Hexlink NFT", "HEXL", "void", "1000", deployer.address, true]
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

        const contract = await ethers.getContractAt("HexlinkErc721Impl", deloyed);
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
        expect(await contract.getMintedCount(deployer.address)).to.eq(0);
        const tx2 = await contract.connect(deployer).mint(
            deployer.address, signature
        );
        expect(await contract.getMintedCount(deployer.address)).to.eq(1);
        console.log(tx2);

        await expect(
            contract.connect(deployer).mint(
                deployer.address, signature
            )
        ).to.be.revertedWith("Already minted");

        await contract.connect(deployer)[
            "safeTransferFrom(address,address,uint256)"
        ](
            deployer.address, validator.address, 1
        );
    });

    it("deploy soul bound erc721", async function() {
        const { deployer, validator } = await ethers.getNamedSigners();

        const tokenFactory = await run("token_factory", {});
        const erc721Iface = await iface("HexlinkErc721Impl");
        const initData = erc721Iface.encodeFunctionData(
            "init",
            ["Hexlink NFT", "HEXL", "void", "1000", deployer.address, false]
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

        const contract = await ethers.getContractAt("HexlinkErc721Impl", deloyed);
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
        expect(await contract.getMintedCount(deployer.address)).to.eq(0);
        const tx2 = await contract.connect(deployer).mint(
            deployer.address, signature
        );
        console.log(tx2);
        expect(await contract.getMintedCount(deployer.address)).to.eq(1);

        await expect(
            contract.connect(deployer).mint(
                deployer.address, signature
            )
        ).to.be.revertedWith("Already minted");

        await expect(
            contract.connect(deployer)[
                "safeTransferFrom(address,address,uint256)"
            ](
                deployer.address, validator.address, 1
            )
        ).to.be.revertedWith("Transfer not allowed");
    });
});
