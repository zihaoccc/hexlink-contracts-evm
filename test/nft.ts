import { expect } from "chai";
import { ethers, deployments, artifacts, run, network } from "hardhat";
import { getHexlinkSwap, getHexlinkToken, setGasPrice } from "./swap";

async function iface(contract: string) {
    const artifact = await artifacts.readArtifact(contract);
    return new ethers.utils.Interface(artifact.abi);
}

describe("Hexlink Redpacket", function() {
    beforeEach(async function() {
      await deployments.fixture(["HEXL"]);
    });

    it("deploy erc721", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

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

        await contract.connect(deployer).deposit(
            {value: ethers.utils.parseEther("0.5")}
        );
        // mint
        const message = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256", "address", "address", "address"],
                [
                    network.config.chainId,
                    deloyed,
                    deployer.address,
                    tester.address
                ]
            )
        );
        console.log(message);
        const signature = await deployer.signMessage(
            ethers.utils.arrayify(message)
        );
        expect(await contract.getMintedCount(deployer.address)).to.eq(0);
        const tx2 = await contract.connect(deployer).mint(
            deployer.address, tester.address, signature
        );
        expect(await contract.getMintedCount(deployer.address)).to.eq(1);
        console.log(tx2);

        await expect(
            contract.connect(deployer).mint(
                deployer.address,
                tester.address,
                signature
            )
        ).to.be.revertedWith("Already minted");

        await contract.connect(deployer)[
            "safeTransferFrom(address,address,uint256)"
        ](
            deployer.address, validator.address, 1
        );
    });

    it("deploy soul bound erc721", async function() {
        const { deployer, validator, tester } = await ethers.getNamedSigners();

        const swap = await getHexlinkSwap();
        const token = await getHexlinkToken();
        await setGasPrice(token, swap);
        await swap.connect(deployer).deposit({value: ethers.utils.parseEther("1.0")});

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
        await contract.connect(deployer).deposit(
            {value: ethers.utils.parseEther("0.5")}
        );

        // mint
        const message = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["uint256", "address", "address", "address"],
                [
                    network.config.chainId,
                    deloyed,
                    deployer.address,
                    tester.address
                ]
            )
        );
        console.log(message);
        const signature = await deployer.signMessage(
            ethers.utils.arrayify(message)
        );
        expect(await contract.getMintedCount(deployer.address)).to.eq(0);
        const tx2 = await contract.connect(deployer).mint(
            deployer.address, tester.address, signature
        );

        const receipt2 = await tx2.wait();
        const e2 = receipt2.events.find((e: any) => e.event === "GasSponsorship");
        expect(e2.args.receiver).to.eq(tester.address);
        expect(await ethers.provider.getBalance(tester.address), e2.args.payment);
        console.log("real gas price = "  + receipt2.effectiveGasPrice.toNumber());
        console.log("real gas cost = "  + receipt2.gasUsed.toNumber());
        console.log("real gas cost is " + receipt2.gasUsed.mul(receipt2.effectiveGasPrice).toString());
        console.log("gas sponsorship is " + e2.args.payment.toString());
        expect(await contract.getMintedCount(deployer.address)).to.eq(1);

        await expect(
            contract.connect(deployer).mint(
                deployer.address,
                tester.address,
                signature
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
