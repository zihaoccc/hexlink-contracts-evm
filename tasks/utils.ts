import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import { ethers } from "ethers";

task("get_admin", "get admin address")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const { deployer } = await hre.getNamedAccounts();
        const adminMap = JSON.parse((process.env.HEXLINK_ADMIN || "{}"));
        const admin = adminMap[hre.network.name];
        return admin ? ethers.utils.getAddress(admin) : deployer;
    });