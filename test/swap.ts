import { ethers, deployments, run } from "hardhat";
import { Contract } from "ethers";

export async function getHexlinkSwap() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkSwapProxy");
    return await ethers.getContractAt("HexlinkSwapImpl", deployment.address);
}

export async function setGasPrice(token: Contract, swap: Contract) {
    const data = swap.interface.encodeFunctionData(
        "setPrice",
        [token.address, ethers.BigNumber.from(10).pow(18).mul(1000)]
    );
    await run("admin_schedule_and_exec", {target: swap.address, data})
}

export async function getHexlinkToken() : Promise<Contract> {
    const deployment = await deployments.get("HexlinkToken");
    return await ethers.getContractAt("HexlinkToken", deployment.address);
}