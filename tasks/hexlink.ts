import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, Contract } from "ethers";

const genNameHash = function(name: string) : string {
    return ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes(name)
    );
};

const getHexlink = async function(
    hre: HardhatRuntimeEnvironment
): Promise<Contract> {
    const deployment = await hre.deployments.get("HexlinkProxy");
    return await hre.ethers.getContractAt(
        "HexlinkUpgradeable",
        ethers.utils.getAddress(deployment.address)
    );
}

const getDefaultAddress = async function(
    hexlink: string,
    name: string,
    hre: HardhatRuntimeEnvironment
): Promise<string> {
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

task("hexlink_check", "check hexlink metadata")
    .setAction(async (_args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        const result = {
            "address": hexlink.address,
            "accountBase": await hexlink.accountBase(),
            "oracleRegistry": await hexlink.oracleRegistry(),
            "authConfig": {
                twoStageLock: (await hexlink.twoStageLock()).toNumber(),
                ttl: (await hexlink.ttl()).toNumber(),
            },
            "owner": await hexlink.owner(),
            "implementation": await hexlink.implementation(),
        }
        console.log(result);
        return result;
    });

task("account", "Prints account address")
    .addParam("name")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const nameHash = genNameHash(args.name);
        const hexlink = await getHexlink(hre);
        console.log("name hash is " + nameHash);
        const account = await hexlink.addressOfName(nameHash);
        console.log("account is " + account);
        return account;
    });

task("nonce", "get current nonce")
    .addParam("name")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        const nameHash = genNameHash(args.name);
        return await hexlink.nonce(nameHash);
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

task("deployAccount", "deploy a new account per given email")
    .addParam("name")
    .addParam("owner")
    .addParam("proof", "the auth proof")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const {deployer} = await hre.getNamedAccounts();
        const hexlink = await getHexlink(hre);

        const nameHash = genNameHash(args.name);
        const initData = hexlink.interface.encodeFunctionData(
            "init", [args.owner]
        );
        const tx = await hexlink.connect(deployer).deploy(
            nameHash,
            initData,
            args.proof
        );
        await processTx(tx);
        const account = getDefaultAddress(hexlink.address, args.name, hre);
        return account;
    });

task("resetAccount", "reset the account address")
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
