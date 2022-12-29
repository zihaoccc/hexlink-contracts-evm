import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import config from '../config.json';

const getAdminConfig = async function(network: string) {
    let conf = config[network];
    if (conf) {
        return {
            minDelay: Number(conf["timelock"].minDelay),
            proposers: [ethers.utils.getAddress(conf["safe"])],
            executors: [ethers.utils.getAddress(conf["safe"])]
        }
    } else {
        const { deployer } = await hre.getNamedAccounts();
        return {
            minDelay: 0,
            proposers: [deployer],
            executors: [deployer]
        }
    }
}

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const { minDelay, proposers, executors } = await getAdminConfig(hre.network.name);
  await deploy("HexlinkAdmin", {
    from: deployer,
    args: [minDelay, proposers, executors],
    log: true,
    autoMine: true
  });
};

export default func;
func.tags = ["HEXL", "ADMIN"];
