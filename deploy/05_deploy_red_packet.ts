import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import * as config from '../config.json';
import { ethers } from "hardhat";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  await deploy("HappyRedPacketImpl", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true
  });

  try {
    const proxy = await deployments.get("HappyRedPacket");
    console.log("reusing HappyRedPacket at " + proxy.address);
    console.log("HappyRedPacket proxy is already deployed, please upgrade instead of deploying a new one");
  } catch {
    const impl = await deployments.get("HappyRedPacketImpl");
    const admin = await hre.deployments.get("HexlinkAdmin");
    const implContract = await hre.ethers.getContractAt(
      "HappyRedPacketImpl",
      impl.address
    );
    const initData = implContract.interface.encodeFunctionData(
      "initOwner", [admin.address]
    );
    await deploy("HappyRedPacket", {
      from: deployer,
      args: [impl.address, initData],
      log: true,
      autoMine: true,
    });
  }
};

export default func;
func.tags = ["HEXL", "APP"];
