import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAdmin } from "../utils/amdin";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  // deploy hexlink impl
  const accountProxy = await deployments.get("AccountProxy");
  const hexlinkImpl = await deploy("HexlinkUpgradable", {
    from: deployer,
    args: [accountProxy.address],
    log: true,
    autoMine: true,
  });

  // deploy hexlink proxy
  const hexlinkDeployment = await deploy("ERC1967Proxy", {
    from: deployer,
    args: [hexlinkImpl.address, ""],
    log: true,
    autoMine: true,
  });

  const hexlinkContract = await hre.ethers.getContractAt(
    "HexlinkUpgradeable",
    hexlinkDeployment.address
  );
  const admin = getAdmin(hre);
  const oracleRegistry = await deployments.get(
    "IdentityOracleRegistry"
  );
  await hexlinkContract.init(admin, oracleRegistry.address);
};

export default func;
func.tags = ["HEXL", "CORE", "TEST"];
