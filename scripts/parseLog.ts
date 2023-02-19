import { ethers } from "hardhat";

function equal(one: string | undefined, two: string | undefined) : boolean {
  return (one || "").toLowerCase() == (two || "").toLowerCase();
}

async function main() {
  const receipt = await ethers.provider.getTransactionReceipt("0xcba7f0259d6eeb38fcc54204cb454de46fea28326e13848641bd224ed8e9c234");
  const erc721 : ethers.Contact = await ethers.getContractAt(
    "HexlinkErc721", "0xe354E694C89B4Dfea9d22ae4eEADca3915E3a6DD"
  );
  const events = receipt.logs.filter(
      (log: any) => log.address.toLowerCase() === erc721.address.toLowerCase()
  ).map((log: any) => erc721.interface.parseLog(log));
  const event = events.find(
      (e: any) => e.name === "Transfer" && equal(
        e.args.from, ethers.constants.AddressZero
    )
  );
  console.log(event);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});