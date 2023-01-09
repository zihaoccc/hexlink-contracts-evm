import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import * as config from '../config.json';
import { ethers } from "ethers";

const getAdminConfig = async function(hre: HardhatRuntimeEnvironment) {
    let netConf = config[hre.network.name as keyof typeof config] || {};
    if (netConf["safe"] !== undefined) {
        return {
            minDelay: Number(netConf["timelock"].minDelay),
            proposers: [ethers.utils.getAddress(netConf["safe"])],
            executors: [ethers.utils.getAddress(netConf["safe"])]
        }
    } else {
        const { deployer } = await hre.getNamedAccounts();
        return {
            minDelay: Number(netConf["timelock"]?.minDelay || 0),
            proposers: [deployer],
            executors: [deployer]
        }
    }
}

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const { minDelay, proposers, executors } = await getAdminConfig(hre);
  await deploy("HexlinkAdmin", {
    from: deployer,
    args: [minDelay, proposers, executors],
    log: true,
    autoMine: true
  });
};

export default func;
func.tags = ["HEXL", "ADMIN"];
