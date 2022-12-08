import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";
import { ethers } from "ethers";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  // deploy account implementation
  const accountImpl = await deploy("AccountSimpleV2", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });

  // deploy account beacon contract
  const adminMap = JSON.parse((process.env.HEXLINK_ADMIN!));
  const admin = ethers.utils.getAddress(adminMap[hre.network.name]) || deployer;
  const beacon = await deploy("AccountBeacon", {
    from: deployer,
    args: [accountImpl.address, admin],
    log: true,
    autoMine: true,
  });

  // deploy beacon proxy contract
  const accountProxy = await deploy("AccountProxy", {
    from: deployer,
    args: [beacon.address],
    log: true,
    autoMine: true,
  });

  // deploy hexlink impl
  const hexlinkImpl = await deploy("HexlinkUpgradable", {
    from: deployer,
    args: [accountProxy.address],
    log: true,
    autoMine: true,
  });

  // deploy hexlink proxy
  const hexlink = await deploy("ERC1967Proxy", {
    from: deployer,
    args: [hexlinkImpl.address],
    log: true,
    autoMine: true,
  });
};

export default func;
func.tags = ["HEXL", "TEST"];
