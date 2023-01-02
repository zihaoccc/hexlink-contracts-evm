import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, Contract, BigNumber, Signer } from "ethers";

const genNonce = async function(hexlink: Contract, args: {
    name: string,
    nonce: string
}) : Promise<BigNumber> {
    return args.nonce !== undefined
        ? BigNumber.from(args.nonce)
        : await hexlink.nonce(args.name);
}

const getHexlink = async function(
    hre: HardhatRuntimeEnvironment
): Promise<Contract> {
    const deployment = await hre.deployments.get("HexlinkProxy");
    return await hre.ethers.getContractAt(
        "Hexlink",
        ethers.utils.getAddress(deployment.address)
    );
}

const buildAuthProof = async function(
    hre: HardhatRuntimeEnvironment,
    params: {
        name: string,
        func: string,
        data: string | [],
        validator: Signer,
        hexlink: Contract,
        identityType: Number,
        authType: Number,
        nonce: BigNumber
    }
) {
    const requestId = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes4", "bytes", "address", "uint256", "uint256"],
        [
            params.func,
            params.data,
            params.hexlink.address,
            hre.network.config.chainId,
            params.nonce
        ]
      )
    );
    const issuedAt = Math.round(Date.now() / 1000);
    const message = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes32", "bytes32", "uint256", "uint256", "uint256"],
        [params.name, requestId, issuedAt, params.identityType, params.authType]
      )
    );
    const signature = await params.validator.signMessage(
      ethers.utils.arrayify(message)
    );
    const encodedSig = ethers.utils.defaultAbiCoder.encode(
      ["address", "bytes"], [await params.validator.getAddress(), signature]
    )
    return {
      issuedAt,
      identityType: params.identityType,
      authType: params.authType,
      signature: encodedSig
    };
};

task("build_deploy_auth_proof", "build auth proof")
    .addParam("name")
    .addOptionalParam("data")
    .addOptionalParam("identityType")
    .addOptionalParam("authType")
    .addOptionalParam("nonce")
    .addOptionalParam("validator")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        const signers = await hre.ethers.getNamedSigners();
        const validator = args.validator ? signers[args.validator] : signers.validator,
        const data = args.data ? args.data : [];
        const identityType = args.identityType ? Number(args.identityType) : 1;
        const authType = args.authType ? Number(args.authType) : 1;
        const nonce = await genNonce(hexlink, args);
        return await buildAuthProof(hre, {
            name: args.name,
            func: hexlink.interface.getSighash("deploy"),
            data,
            validator,
            hexlink,
            nonce,
            identityType,
            authType,
        });    
    });

task("build_reset_auth_proof", "build auth proof")
    .addParam("name")
    .addParam("account")
    .addOptionalParam("identityType")
    .addOptionalParam("authType")
    .addOptionalParam("nonce")
    .addOptionalParam("validator")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        const hexlink = await getHexlink(hre);
        const signers = await hre.ethers.getNamedSigners();
        const validator = args.validator ? signers[args.validator] : signers.validator,
        const data = ethers.utils.defaultAbiCoder.encode(
            ["address"], [args.account]
        );
        const identityType = args.identityType ? Number(args.identityType) : 1;
        const authType = args.authType ? Number(args.authType) : 1;
        const nonce = await genNonce(hexlink, args);
        return await buildAuthProof(hre, {
            name: args.name,
            func: hexlink.interface.getSighash("reset"),
            data,
            validator,
            hexlink,
            nonce,
            identityType,
            authType,
        });    
    });