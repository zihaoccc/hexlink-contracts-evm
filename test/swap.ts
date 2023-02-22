import { ethers, deployments } from "hardhat";
import { Contract } from "ethers";

export async function getHexlinkSwap() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkSwapProxy");
    return await ethers.getContractAt("HexlinkSwapImpl", deployment.address);
}

export async function setGasPrice(token: Contract, swap: Contract) {
    const { deployer } = await ethers.getNamedSigners();
    await swap.connect(deployer).setPrice(
        token.address,
        ethers.BigNumber.from(10).pow(18).mul(1000)
    );
}

export async function getHexlinkToken() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkToken");
    return await ethers.getContractAt("HexlinkToken", deployment.address);
}