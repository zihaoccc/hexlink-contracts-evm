import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import * as config from '../config.json';
import { ethers } from "hardhat";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  
  const netConf = config[hre.network.name as keyof typeof config] || {};
  const swapRouter = netConf["gasStation"]
    ? netConf["gasStation"]["swapRouter"]
    : ethers.constants.AddressZero;
  const wrapped = netConf["gasStation"]
    ? netConf["gasStation"]["wrapped"]
    : ethers.constants.AddressZero;

  console.log("Using swap router: " + swapRouter);
  console.log("Using wrapped eth: " + wrapped);
  await deploy("GasStation", {
    from: deployer,
    args: [swapRouter, wrapped],
    log: true,
    autoMine: true
  });

  await deploy("HappyRedPacket", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true
  });

  // deploy hexlink helper
  const hexlink = await deployments.get("HexlinkProxy");
  const redPacket = await deployments.get("HappyRedPacket");
  const gasStation = await deployments.get("GasStation");
  await deploy("HexlinkHelper", {
    from: deployer,
    args: [
      hexlink.address,
      gasStation.address,
      redPacket.address
    ],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "APP"];
