import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import { ethers, Contract } from "ethers";

async function createOracle(
    oracle: Contract,
    name: string,
    hre: HardhatRuntimeEnvironment
): Promise<string> {
    const adminDeployed = await hre.deployments.get("HexlinkAdmin");
    const tx = await oracle.clone(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name)),
        adminDeployed.address
    );
    const receipt = await tx.wait();
    const events = receipt.logs.map((log: any) => oracle.interface.parseLog(log));
    const event = events.find((e: any) => e.name == "Clone");
    console.log("Oracle for " + name + " is created at " + event.args.cloned);
    return event.args.cloned;
}

const getOracleImpl = async function(hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments} = hre;
    const deployment = await deployments.get("SimpleIdentityOracle");
    return await ethers.getContractAt("SimpleIdentityOracle", deployment.address);
};

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

task("init_oracle", "setup email otp and twitter oauth oracle")
    .addParam("validator")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const oracleImpl = await getOracleImpl(hre);
        const emailOtp = await createOracle(oracleImpl, "EMAIL_OTP", hre);
        const twitterOAuth = await createOracle(oracleImpl, "TWITTER_OAUTH", hre);
        const registry = await getRegistry(hre);
        const data = registry.interface.encodeFunctionData(
            "registerBatch",
            [[
                {identityType: 1, authType: 1}, // email otp 
                {identityType: 4, authType: 2}, // twitter oauth
            ], [emailOtp, twitterOAuth]]
        );
        await hre.run("admin_schedule_and_exec", {target: registry.address, data})
        // register validator
        await hre.run(
            "register_validator",
            {oracle: emailOtp, validator: args.validator}
        );
        await hre.run(
            "register_validator",
            {oracle: twitterOAuth, validator: args.validator}
        );
    });

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
        await hre.run("admin_schedule_and_exec", {target: oracle.address, data});
    });