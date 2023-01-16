import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import * as config from '../config.json';
import { ethers } from "hardhat";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  await deploy("HappyRedPacket", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true
  });

  // deploy hexlink proxy
  try {
    const proxy = await deployments.get("HappyRedPacketProxy");
    console.log("reusing HappyRedPacketProxy at " + proxy.address);
    console.log("HappyRedPacketProxy proxy is already deployed, please upgrade instead of deploying a new one");
  } catch {
    const impl = await deployments.get("HappyRedPacket");
    const admin = await hre.deployments.get("HexlinkAdmin");
    const implContract = await hre.ethers.getContractAt(
      "HappyRedPacket",
      impl.address
    );
    const initData = implContract.interface.encodeFunctionData(
      "initOwner", [admin.address]
    );
    await deploy("HappyRedPacketProxy", {
      from: deployer,
      args: [impl.address, initData],
      log: true,
      autoMine: true,
    });
  }
};

export default func;
func.tags = ["HEXL", "APP"];
