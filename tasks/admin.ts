import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, BigNumber } from "ethers";

task("admin_exec", "schedule and execute")
    .addParam("target")
    .addParam("data")
    .addOptionalParam("value")
    .addOptionalParam("predecessor")
    .addOptionalParam("salt")
    .addOptionalParam("delay")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const { deployer } = await hre.ethers.getNamedSigners();
        const adminDeployed = await deployments.get("HexlinkAdmin");
        const admin = await hre.ethers.getContractAt(
            "TimelockController",
            adminDeployed.address
        );

        const delay = BigNumber.from(args.delay || 0);
        await admin.connect(deployer).schedule(
            args.target, // target
            BigNumber.from(args.value || 0), // value
            args.data, // tx data
            args.predecessor || ethers.constants.HashZero, // predecessor
            args.salt || ethers.constants.HashZero,  // salt
            delay // delay
        );

        if (delay.toNumber() > 0) {
            await new Promise(f => setTimeout(delay.toNumber(), 1000));
        }

        await admin.connect(deployer).execute(
            args.target, // target
            BigNumber.from(args.value || 0), // value
            args.data, // tx data
            args.predecessor || ethers.constants.HashZero, // predecessor
            args.salt || ethers.constants.HashZero,  // salt
        );
    });