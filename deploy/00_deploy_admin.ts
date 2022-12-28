import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";


const getAdminConfig = async function() {
    let config = JSON.parse((process.env.HEXLINK_CONFIG || "{}"));
    config = config[hre.network.name];
    if (config && config["timelock"]) {
        return {
            minDelay: Number(config.minDelay),
            proposers: config.proposers.map(p => ethers.utils.getAddress(p)),
            executors: config.executors.map(e => ethers.utils.getAddress(e))
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

  const { minDelay, proposers, executors } = await getAdminConfig();
  await deploy("HexlinkAdmin", {
    from: deployer,
    args: [minDelay, proposers, executors],
    log: true,
    autoMine: true
  });
};

export default func;
func.tags = ["HEXL", "ADMIN"];
