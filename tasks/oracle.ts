import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";

const getOracle = async function(oracle: string, hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments} = hre;
    const deployment = await deployments.get("SimpleIdentityOracle");
    return await ethers.getContractAt("SimpleIdentityOracle", oracle);
};

const getRegistry = async function(hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments} = hre;
    const deployment = await deployments.get("IdentityOracleRegistry");
    return await ethers.getContractAt("IdentityOracleRegistry", deployment.address);
};

task("register_oracle", "register oracle contract for identity and auth type")
    .addParam("identity")
    .addParam("auth")
    .addParam("oracle", "the oracle type")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const registry = await getRegistry(hre);
        const data = registry.interface.encodeFunctionData(
            "regsiter",
            [{
                identityType: Number(args.identity),
                authType: Number(args.auth)
            }, ethers.utils.getAddress(args.oracle)]
        )
        await hre.run("admin_schedule_and_exec", {target: registry.address, data});
    });

task("register_validator", "register validator at oracle contract")
    .addParam("oracle")
    .addParam("validator")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const oracle = await getOracle(ethers.utils.getAddress(args.oracle), hre);
        const data = oracle.interface.encodeFunctionData(
            "register",
            [ethers.utils.getAddress(args.validator), true]
        )
        console.log("Registering valdiator " + args.validator + " at oracle " + args.oracle);
        await hre.run("admin_schedule_and_exec", {target: oracle.address, data});
    });