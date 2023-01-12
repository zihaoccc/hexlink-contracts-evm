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
};

export default func;
func.tags = ["HEXL", "APP"];
