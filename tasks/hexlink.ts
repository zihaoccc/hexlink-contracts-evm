import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";
import { getAdmin } from "../utils/amdin";

const genNameHash = function(name: string) {
    return ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(name)
    );
};

const getAccountProxy = async function(hre: HardhatRuntimeEnvironment) {
    const {ethers, deployments} = hre;
    const deployment = await deployments.get("AccountProxy");
    return await ethers.getContractAt("AccountProxy", deployment.address);
};

const getHexlink = async function(hre: HardhatRuntimeEnvironment) {
    const hexlinkMap = JSON.parse((process.env.HEXLINK_ADDRESS!));
    const hexlink = adminMap[hre.network.name];
    assert(hexlink, "Hexlink contract not found");
    return await ethers.getContractAt(
        "Hexlink",
        ethers.utils.getAddress(hexlink)
    );
}

const getDefaultAddress = async function(
    hexlink: string,
    name: string,
    hre: HardhatRuntimeEnvironment
) {
    const artifact = await hre.artifacts.readArtifact("AccountProxy");
    const initCodeHash = ethers.utils.keccak256(artifact.bytecode);
    return ethers.utils.getCreate2Address(
        hexlink, genNameHash(name), initCodeHash
    );
}

const processTx = async function(tx: any) {
    const receipt = await tx.wait();
    const gas = receipt.gasUsed.mul(
        receipt.effectiveGasPrice
    ).div(1000000000);
    console.log(
        // eslint-disable-next-line max-len
        `Processed transaction (tx: ${tx.hash}) with ${gas} gas`
    );
}

task("accountBase", "Prints account base address")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        return await hexlink.accountBase();
    });

task("addressOfName", "Prints account address")
    .addParam("name")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const nameHash = genNameHash(args.name);
        const hexlink = await getHexlink(hre);
        const account = await hexlink.addressOfName(nameHash);
        return account;
    });

task("nonce", "get current nonce")
    .addParam("name")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        return await hexlink.nonce(nameHash);
    });

task("oracleRegistry", "get oracle registry")
    .addParam("name")
    .setAction(async (_args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        return await hexlink.oracleRegistry();
    });

task("authConfig", "get oracle registry")
    .setAction(async (_args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        return await hexlink.authConfig();
    });

task("bumpNonce", "bump nonce for a name")
    .addParam("name")
    .addParam("proof", "the auth proof")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        const tx = await hexlink.connect(deployer).bumpNonce(
            nameHash,
            args.proof
        );
        await processTx(tx);
        return await hexlink.connect(deployer).nonce(nameHash);
    });

task("deploy", "deploy a new account per given email")
    .addParam("name")
    .addParam("owner")
    .addParam("proof", "the auth proof")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);

        const nameHash = genNameHash(args.name);
        const initData = hexlink.interface.encodeFunctionData("init", [owner]);
        const tx = await hexlink.connect(deployer).deploy(
            nameHash,
            initData,
            args.proof
        );
        await processTx(tx);
        const account = getDefaultAddress(hexlink.address, name);
        return account;
    });

task("reset", "reset the account address")
    .addParam("name")
    .addParam("account")
    .addParam("proof")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        const tx = await hexlink.connect(deployer).reset(
            nameHash,
            args.account,
            args.proof
        );
        await processTx(tx);
    });

task("reset2Fac", "reset the account address with 2fac")
    .addParam("name")
    .addParam("account")
    .addParam("proof1")
    .addParam("proof2")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        const tx = await hexlink.connect(deployer).reset(
            nameHash,
            args.account,
            args.proof1,
            args.proof2
        );
        await processTx(tx);
    });

task("reset2Stage", "reset the account address with 2fac")
    .addParam("name")
    .addParam("account")
    .addParam("authProof")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        const tx = await hexlink.connect(deployer).reset2Stage(
            nameHash,
            args.account,
            args.authProof
        );
        await processTx(tx);
    });