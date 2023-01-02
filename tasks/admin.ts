import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, BigNumber, Signer, Contract } from "ethers";
import config from '../config.json';

import EthersAdapter from '@safe-global/safe-ethers-lib'
import Safe from '@safe-global/safe-core-sdk'
import { SafeTransactionDataPartial } from '@safe-global/safe-core-sdk-types'
import SafeServiceClient, {
    ProposeTransactionProps,
    SafeInfoResponse,
  } from '@safe-global/safe-service-client';

const processArgs = async function(
    timelock: Contract,
    args : {
        target: string,
        data: string,
        predecessor?: string,
        salt?: string,
        value?: string,
        delay?: string
    }
) {
    return [
        args.target,
        BigNumber.from(args.value || 0),
        args.data,
        args.predecessor || ethers.constants.HashZero,
        args.salt || ethers.constants.HashZero,  // salt
        BigNumber.from(args.delay || await timelock.getMinDelay())
    ];
}

function netConf(hre: HardhatRuntimeEnvironment) {
    return config[hre.network.name as keyof typeof config] || {};
}

async function getAdminContract(hre: HardhatRuntimeEnvironment) {
    const adminDeployed = await hre.deployments.get("HexlinkAdmin");
    return await hre.ethers.getContractAt(
        "TimelockController",
        adminDeployed.address
    );
}

async function safeService(
    hre: HardhatRuntimeEnvironment,
    ethAdapter: EthersAdapter
) : Promise<SafeServiceClient> {
    return new SafeServiceClient({
        txServiceUrl: netConf(hre)["safeApi"],
        ethAdapter
    });
}

async function getSafe(
    hre: HardhatRuntimeEnvironment,
    signer: Signer
) : Promise<{safe: Safe, safeService: SafeServiceClient, safeInfo: SafeInfoResponse}> {
    const ethAdapter = new EthersAdapter({ethers, signerOrProvider: signer})
    const safe = await Safe.create({
        ethAdapter,
        safeAddress: netConf(hre)["safe"]
    });
    const service = await safeService(hre, ethAdapter)
    const info: SafeInfoResponse = await service.getSafeInfo(netConf(hre)["safe"])
    return {safe, safeService: service, safeInfo: info};
}

async function proposeOrExectueSafeTx(
    hre: HardhatRuntimeEnvironment,
    signer: Signer,
    tx: SafeTransactionDataPartial
) {
    const { safe, safeService, safeInfo } = await getSafe(hre, signer);
    
    const senderAddress = await (safe.getEthAdapter()).getSignerAddress();
    if (senderAddress == undefined) {
        throw "No signer found for safe transaction";
    }
    if (safeInfo.owners.find(
        (owner) => owner.toLowerCase() === senderAddress.toLowerCase()
    ) == undefined) {
        throw "Signer is not owner of safe";
    }

    const safeTransaction = await safe.createTransaction({ safeTransactionData: tx });
    const signedSafeTransaction = await safe.signTransaction(safeTransaction);
    console.log("Signed safe transaction is ");
    console.log(signedSafeTransaction);

    // if threshold = 1, execute directly
    if (safeInfo.threshold == 1) {
        const executeTxResponse = await safe.executeTransaction(safeTransaction)
        await executeTxResponse.transactionResponse?.wait();
        return;
    }

    // else propose for other owners to confirm
    const safeTxHash = await safe.getTransactionHash(signedSafeTransaction);

    const senderSignature = signedSafeTransaction.signatures.get(senderAddress!);
    if (senderSignature == undefined) {
        throw "Signature not find at transaction";
    }
    const safeAddress = safe.getAddress();
    const transactionConfig: ProposeTransactionProps = {
        safeAddress,
        safeTransactionData: safeTransaction.data,
        safeTxHash,
        senderAddress,
        senderSignature: senderSignature.data
      }
    return await safeService.proposeTransaction(transactionConfig);
}

task("admin_check", "check if has role")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const admin = await getAdminContract(hre);
        const minDelay = await admin.getMinDelay();
        console.log("admin is " + admin.address + ", with min delay as " + minDelay);

        const safe = ethers.utils.getAddress(netConf(hre)["safe"]);
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
        console.log(safe + " is " + (isExecutor ? "" : "not ") +  "executor");

        const isAdmin = await admin.hasRole(
            ethers.utils.keccak256(ethers.utils.toUtf8Bytes("TIMELOCK_ADMIN_ROLE")),
            admin.address
        );
        console.log(admin.address + " is " + (isAdmin ? "" : "not ") +  "admin");
    });

task("admin_schedule", "schedule a tx")
    .addParam("target")
    .addParam("data")
    .addOptionalParam("value")
    .addOptionalParam("predecessor")
    .addOptionalParam("salt")
    .addOptionalParam("delay")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const admin = await getAdminContract(hre);
        const { deployer } = await hre.ethers.getNamedSigners();
        const processed = await processArgs(admin, args);
        if (netConf(hre)["safe"]) {
            const data = admin.interface.encodeFunctionData(
                "schedule",
                processed
            );
            await proposeOrExectueSafeTx(hre, deployer, {
                to: admin.address,
                value: "0",
                data
            });
        } else {
            await admin.connect(deployer).schedule(...processed);
        }
    });

task("admin_exec", "execute a tx")
    .addParam("target")
    .addParam("data")
    .addOptionalParam("value")
    .addOptionalParam("predecessor")
    .addOptionalParam("salt")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const admin = await getAdminContract(hre);
        const { deployer } = await hre.ethers.getNamedSigners();
        const processed = await processArgs(admin, args);
        processed.pop();
        if (netConf(hre)["safe"]) {
            const data = admin.interface.encodeFunctionData(
                "execute",
                processed
            );
            await proposeOrExectueSafeTx(hre, deployer, {
                to: admin.address,
                value: "0",
                data
            });
        } else {
            await admin.connect(deployer).execute(...processed);
        }
    });

task("admin_schedule_and_exec", "schedule and execute")
    .addParam("target")
    .addParam("data")
    .addOptionalParam("value")
    .addOptionalParam("predecessor")
    .addOptionalParam("salt")
    .addOptionalParam("delay")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        await hre.run("admin_schedule", args);
        const delay = Number(args.delay || 0);
        if (delay > 0) {
            await new Promise(f => setTimeout(() =>{
                console.log("Will wait for " + delay + "s for timelock...")
            }, 1000));
        }
        await hre.run("admin_exec", args);
    });

task("admin_schedule_or_exec", "schedule and execute")
    .addParam("target")
    .addParam("data")
    .addOptionalParam("value")
    .addOptionalParam("predecessor")
    .addOptionalParam("salt")
    .addOptionalParam("delay")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const admin = await getAdminContract(hre);
        const processed = await processArgs(admin, args);
        processed.pop();
        const operationId = ethers.utils.keccak256(
            ethers.utils.defaultAbiCoder.encode(
                ["address", "uint256", "bytes", "bytes32", "bytes32"],
                processed
            )
        );
        if (await admin.isOperationReady(operationId)) {
            console.log("Operation is ready, will execute.");
            await hre.run("admin_exec", args);
        } else if (await admin.isOperation(operationId)) {
            console.log("Operation is pending, no action.");
        } else {
            console.log("Operation is not scheduled, will schedule.");
            await hre.run("admin_schedule", args);
        }
    });

task("register_oracle", "register oracle contract for identity and auth type")
    .addParam("identity")
    .addParam("auth")
    .addParam("oracle")
    .addFlag("waitForExec")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const deployment = await hre.deployments.get("IdentityOracleRegistry");
        const registry = await hre.ethers.getContractAt(
            "IdentityOracleRegistry",
            deployment.address
        );
        const data = registry.interface.encodeFunctionData(
            "regsiter",
            [{
                identityType: Number(args.identity),
                authType: Number(args.auth)
            }, ethers.utils.getAddress(args.oracle)]
        )
        if (args.waitForExec) {
            await hre.run("admin_schedule_and_exec", { target: registry.address, data });
        } else {
            await hre.run("admin_schedule_or_exec", { target: registry.address, data });
        }
    });

task("register_validator", "register validator at oracle contract")
    .addParam("oracle")
    .addParam("validator")
    .addFlag("waitForExec")
    .setAction(async (args: any, hre : HardhatRuntimeEnvironment) => {
        const oracle = await hre.ethers.getContractAt("SimpleIdentityOracle", args.oracle);
        const data = oracle.interface.encodeFunctionData(
            "register",
            [ethers.utils.getAddress(args.validator), true]
        )
        console.log("Registering valdiator " + args.validator + " at oracle " + args.oracle);
        if (args.waitForExec) {
            await hre.run("admin_schedule_and_exec", { target: oracle.address, data });
        } else {
            await hre.run("admin_schedule_or_exec", { target: oracle.address, data });
        }
    });

task("set_oracle_registry", "set oracle registry")
    .addParam("registry")
    .addFlag("waitForExec")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const deployment = await hre.deployments.get("HexlinkProxy");
        const hexlink = await hre.ethers.getContractAt(
            "Hexlink",
            ethers.utils.getAddress(deployment.address)
        );
        const data = hexlink.interface.encodeFunctionData(
            "setOracleRegistry",
            [args.registry]
        );
        if (args.waitForExec) {
            await hre.run("admin_schedule_and_exec", { target: hexlink.address, data });
        } else {
            await hre.run("admin_schedule_or_exec", { target: hexlink.address, data });
        }
    });