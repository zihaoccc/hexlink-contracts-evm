import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  // deploy hexlink impl
  const accountProxy = await deployments.get("AccountProxy");
  const hexlinkImpl = await deploy("HexlinkUpgradeable", {
    from: deployer,
    args: [accountProxy.address],
    log: true,
    autoMine: true,
  });

  // deploy hexlink proxy
  const hexlinkDeployment = await deploy("HexlinkProxy", {
    from: deployer,
    args: [hexlinkImpl.address, []],
    log: true,
    autoMine: true,
  });

  const hexlinkContract = await hre.ethers.getContractAt(
    "HexlinkUpgradeable",
    hexlinkDeployment.address
  );
  const admin = await hre.run("get_admin", {})
  const oracleRegistry = await deployments.get(
    "IdentityOracleRegistry"
  );
  await hexlinkContract.init(admin, oracleRegistry.address);
};

export default func;
func.tags = ["HEXL", "CORE", "TEST"];
