import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import * as config from '../config.json';

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  
  const netConf = config[hre.network.name as keyof typeof config];
  if (netConf) {
    await deploy("GasStation", {
        from: deployer,
        args: [
            netConf["gasStation"]["swapRouter"],
            netConf["gasStation"]["wrapped"]
        ],
        log: true,
        autoMine: true
      });
    
      await deploy("RedPocket", {
        from: deployer,
        args: [],
        log: true,
        autoMine: true
      });
  }
};

export default func;
func.tags = ["HEXL", "ADMIN"];
