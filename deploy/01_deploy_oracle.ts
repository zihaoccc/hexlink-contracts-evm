import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import { ethers, Contract } from "ethers";
import config from '../config.json';

function netConf(hre: HardhatRuntimeEnvironment) {
    return config[hre.network.name as keyof typeof config] || {};
}

async function createOracle(
  name: string,
  admin: string,
  hre: HardhatRuntimeEnvironment
): Promise<string> {
  const oracleImpl = await hre.deployments.get("SimpleIdentityOracle");
  const { deployer } = await hre.ethers.getNamedSigners();
  const oracle = await hre.ethers.getContractAt("SimpleIdentityOracle", oracleImpl.address);
  const tx = await oracle.connect(deployer).clone(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name))
  );
  const receipt = await tx.wait();
  const events = receipt.logs.map((log: any) => oracle.interface.parseLog(log));
  const event = events.find((e: any) => e.name == "Cloned");
  const deployed = event.args.cloned;
  console.log("Oracle for " + name + " is created at " + deployed);

  // register validator
  const newOracle = await hre.ethers.getContractAt("SimpleIdentityOracle", deployed);
  let validator = netConf(hre)["validator"];
  if (validator == undefined) {
      validator = (await hre.getNamedAccounts())["validator"];
  }
  console.log("Registering valdiator " + validator + " at oracle " + deployed);
  await newOracle.connect(deployer).init(admin, [validator], [true]);
  return deployed;
}

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const admin = await hre.deployments.get("HexlinkAdmin");

  await deploy("SimpleIdentityOracle", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true
  });

  const oracles = netConf(hre)["oracles"] || {};
  let emailOtp = oracles["EMAIL_OTP"];
  if (emailOtp == undefined) {
    emailOtp = await createOracle("EMAIL_OTP", admin.address, hre);
  }
  let twitterOAuth = oracles["TWITTER_OAUTH"];
  if (twitterOAuth == undefined) {
    twitterOAuth = await createOracle("TWITTER_OAUTH", admin.address, hre);
  }
  
  await deploy("IdentityOracleRegistry", {
    from: deployer,
    args: [
      admin.address, [
          {identityType: 1, authType: 1}, // email otp 
          {identityType: 4, authType: 2}, // twitter oauth
      ], [emailOtp, twitterOAuth]],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "ORACLE"];
