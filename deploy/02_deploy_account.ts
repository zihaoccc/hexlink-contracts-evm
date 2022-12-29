import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  // deploy account implementation
  await deploy("AccountSimple", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  // deploy account beacon contract
  const accountImpl = await hre.deployments.get("AccountSimple");
  const admin = await hre.deployments.get("HexlinkAdmin");
  await deploy("AccountBeacon", {
    from: deployer,
    args: [accountImpl.address, admin.address],
    log: true,
    autoMine: true,
  });

  // deploy beacon proxy contract
  const beacon = await hre.deployments.get("AccountBeacon");
  await deploy("AccountProxy", {
    from: deployer,
    args: [beacon.address],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "ACCOUNT"];
