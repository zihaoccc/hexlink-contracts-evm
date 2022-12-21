import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import { ethers, Contract } from "ethers";

interface OracleSelector {
    identityType: number;
    authType: number;
}

async function createOracle(
    oracle: Contract,
    name: string,
    hre: HardhatRuntimeEnvironment
): Promise<string> {
    const { deployer } = await hre.getNamedAccounts();
    const tx = await oracle.clone(
        ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name)),
        deployer
    );
    const receipt = await tx.wait();
    const events = receipt.logs.map((log: any) => oracle.interface.parseLog(log));
    const event = events.find((e: any) => e.name == "Clone");
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
    .setAction(async (_args, hre : HardhatRuntimeEnvironment) => {
        const oracleImpl = await getOracleImpl(hre);
        const emailOtp = await createOracle(oracleImpl, "EMAIL_OTP", hre);
        const twitterOAuth = await createOracle(oracleImpl, "TWITTER_OAUTH", hre);
        const registry = await getRegistry(hre);
        await registry.registerBatch([
            {identityType: 1, authType: 1}, // email otp 
            {identityType: 4, authType: 2}, // twitter oauth
        ], [emailOtp, twitterOAuth]);
        return [emailOtp, twitterOAuth];
    });

task("register_oracle", "register oracle contract for identity and auth type")
    .addParam("identity")
    .addParam("auth")
    .addParam("oracle", "the oracle type")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const registry = await getRegistry(hre);
        await registry.regsiter(
            {
                identityType: Number(args.identity),
                authType: Number(args.auth)
            }, ethers.utils.getAddress(args.oracle)
        );
    });

task("register_validator", "register validator at oracle contract")
    .addParam("oracle")
    .addParam("validator")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const oracle = await getOracle(ethers.utils.getAddress(args.oracle), hre);
        await oracle.register(ethers.utils.getAddress(args.validator), true);
    });