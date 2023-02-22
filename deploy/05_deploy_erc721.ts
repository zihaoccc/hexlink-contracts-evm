import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  await deploy("HexlinkErc721Impl", {
    from: deployer,
    log: true,
    autoMine: true,
  });

  try {
    await deployments.get("HexlinkErc721Proxy");
    console.log(
      "HexlinkErc721Proxy is already deployed, please " + 
      "upgrade instead of deploying a new one"
    );
    return;
  } catch {
    const impl = await hre.deployments.get("HexlinkErc721Impl");
    const admin = await hre.deployments.get("HexlinkAdmin");
    await deploy("HexlinkErc721Beacon", {
      from: deployer,
      args: [impl.address, admin.address],
      log: true,
      autoMine: true,
    });

    // deploy beacon proxy contract
    const beacon = await hre.deployments.get("HexlinkErc721Beacon");
    await deploy("HexlinkErc721Proxy", {
      from: deployer,
      args: [beacon.address],
      log: true,
      autoMine: true,
    });
  }
}

export default func;
func.tags = ["HEXL", "ERC721"];