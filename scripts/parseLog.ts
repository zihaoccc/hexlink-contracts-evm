import { ethers, run } from "hardhat";

async function main() {
  const receipt = await ethers.provider.getTransactionReceipt("0xe4245f03ac0d234315494d3858b6f9b62289ff3ef93bda7cb8ff156e876dd975");
  const erc721 : ethers.Contact = await ethers.getContractAt(
    "HexlinkErc721", "0x4C32E04A722d2698a5Dcbe8d433a302A20C0A167"
  );
  const events = receipt.logs.filter(
      (log: any) => log.address.toLowerCase() === erc721.address.toLowerCase()
  ).map((log: any) => erc721.interface.parseLog(log));
  const event = events.find(
      (e: any) => e.name === "Transfer"
  );
  console.log(event);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});