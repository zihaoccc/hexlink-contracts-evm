import {HardhatRuntimeEnvironment} from "hardhat/types";
import {DeployFunction} from "hardhat-deploy/types";

const func: DeployFunction = async function(hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;
  const {deployer} = await getNamedAccounts();

  await deploy("HexlinkSwapImpl", {
    from: deployer,
    log: true,
    autoMine: true,
  });

  try {
    await deployments.get("HexlinkSwapProxy");
    console.log(
      "HexlinkSwap is already deployed, please " + 
      "upgrade instead of deploying a new one"
    );
    return;
  } catch {
    const impl = await hre.deployments.get("HexlinkSwapImpl");
    const implContract = await hre.ethers.getContractAt(
        "HexlinkSwapImpl",
        impl.address
    );
    const admin = await hre.deployments.get("HexlinkAdmin");
    const initData = implContract.interface.encodeFunctionData(
        "init", [admin.address]
    );
    await deploy("HexlinkSwapProxy", {
      from: deployer,
      args: [impl.address, initData],
      log: true,
      autoMine: true,
    });
    await hre.run("set_gas_prices", {nowait: true});
  }
}

export default func;
func.tags = ["HEXL", "SWAP"];