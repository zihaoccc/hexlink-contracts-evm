import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, BigNumber } from "ethers";
import config from '../config.json';

task("admin_check", "check if has role")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const { deployer } = await hre.ethers.getNamedSigners();
        const adminDeployed = await deployments.get("HexlinkAdmin");
        const admin = await hre.ethers.getContractAt(
            "TimelockController",
            adminDeployed.address
        );
        console.log("admin is " + admin.address);

        const safe = ethers.utils.getAddress(config[hre.network.name]["safe"]);
        console.log("Gnosis Safe is " + safe);

        const isProposer = await admin.hasRole(
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("PROPOSER_ROLE")),
            safe
        );
        console.log(safe + " is " + (isProposer ? "" : "not ") +  "proposer");

        const isCanceller = await admin.hasRole(
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("CANCELLER_ROLE")),
            safe
        );
        console.log(safe + " is " + (isCanceller ? "" : "not ") +  "canceller");

        const isExecutor = await admin.hasRole(
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("EXECUTOR_ROLE")),
            safe
        );
        console.log(safe + " is " + (isProposer ? "" : "not ") +  "executor");

        const isAdmin = await admin.hasRole(
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("TIMELOCK_ADMIN_ROLE")),
            admin.address
        );
        console.log(admin.address + " is " + (isAdmin ? "" : "not ") +  "admin");
    });

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