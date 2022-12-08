import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import { ethers } from "ethers";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const adminMap = JSON.parse((process.env.HEXLINK_ADMIN!));
  const admin = ethers.utils.getAddress(adminMap[hre.network.name]) || deployer;

  const oracle = await deploy("SimpleIdentityOracle", {
    from: deployer,
    args: [admin, [], []],
    log: true,
    autoMine: true,
  });

  await deploy("IdentityOracleRegistry", {
    from: deployer,
    args: [admin, [1, 4], [2, 2], [oracle.address, oracle.address]],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "TEST"];
