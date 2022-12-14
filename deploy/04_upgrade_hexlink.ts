import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAdmin } from "../utils/amdin";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();
  const hexlink = await getHexlink();

  // deploy hexlink impl
  const accountProxy = await deployments.get("AccountProxy");
  const hexlinkImpl = await deploy("HexlinkUpgradable", {
    from: deployer,
    args: [accountProxy.address],
    log: true,
    autoMine: true,
  });

  const hexlinkMap = JSON.parse((process.env.HEXLINK_ADDRESS!));
  const hexlink = adminMap[hre.network.name];
  assert(hexlink, "Hexlink contract not found");

  const hexlinkContract = await hre.ethers.getContractAt(
    "UUPSUpgradeable", hexlink
  );
  const tx = await hexlinkContract.upgradeTo(hexlinkImpl);
  const receipt = await tx.wait();
  console.log("Transaction hash: ", tx.hash);
};

export default func;
func.tags = ["HEXL", "CORE", "TEST"];
