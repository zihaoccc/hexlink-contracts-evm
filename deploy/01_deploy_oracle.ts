import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  const admin = await hre.deployments.get("HexlinkAdmin");
  await deploy("SimpleIdentityOracle", {
    from: deployer,
    args: [admin.address],
    log: true,
    autoMine: true
  });

  await deploy("IdentityOracleRegistry", {
    from: deployer,
    args: [admin.address],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "ORACLE"];
