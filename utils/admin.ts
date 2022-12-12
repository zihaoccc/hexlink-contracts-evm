import { ethers } from "ethers";
import {HardhatRuntimeEnvironment} from "hardhat/types";

export async function getAmdin(hre: HardhatRuntimeEnvironment) : Promise<string> {
    const {deployer} = await hre.getNamedAccounts();
    const adminMap = JSON.parse((process.env.HEXLINK_ADMIN!));
    const admin = adminMap[hre.network.name];
    return admin ? ethers.utils.getAddress(admin) : deployer;
}