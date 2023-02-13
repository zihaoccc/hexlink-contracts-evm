import { ethers, run } from "hardhat";

async function main() {
  const receipt = await ethers.provider.getTransactionReceipt("0xea37c6299239dfa24c0137f00d8ad52990a13f1447735126e741bc7afa8e2ce4");
  const tokenFactory = await run("token_factory", {});
  const events = receipt.logs.filter(
      (log: any) => log.address === tokenFactory.address
  ).map((log: any) => tokenFactory.interface.parseLog(log));
  const event = events.find(
      (e: any) => e.name === "Deployed"
  );
  const deloyed = event.args.deployed;

  const contract = await ethers.getContractAt("HexlinkErc721", deloyed);
  console.log(await contract.name());
  console.log(await contract.name());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});