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

  // upgrade hexlink proxy
  const hexlinkDeployment = await deployments.get("HexlinkProxy");
  const hexlink = await hre.ethers.getContractAt(
    "UUPSUpgradeable",
    hexlinkDeployment.address
  );
  const data = hexlink.interface.encodeFunctionData(
    "upgradeTo",
    [hexlinkImpl.address]
  );
  await hre.run("admin_schedule_or_exec", {
    target: hexlink.address,
    data
  });
};

export default func;
func.tags = ["UPGRADE"];