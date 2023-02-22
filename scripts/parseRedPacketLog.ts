import { ethers } from "hardhat";

const iface = new ethers.utils.Interface([
    "event Claimed(bytes32 indexed PacketId, address claimer, uint256 amount)",
]);

function equal(one: string | undefined, two: string | undefined) : boolean {
    return (one || "").toLowerCase() == (two || "").toLowerCase();
}

async function parseClaimed(
    receipt: any,
    packetId: string,
    claimer: string,
) {
    const redpacket : ethers.Contact = await ethers.getContractAt(
        "HappyRedPacketImpl", "0xad7346ebfcd605a9528fcdffe868e5d4772a3362"
    );
    console.log(receipt.logs);
    const events = receipt.logs.filter(
        (log: any) => log.address.toLowerCase() === redpacket.address.toLowerCase()
    ).map((log: any) => redpacket.interface.parseLog(log));
    console.log(events);
    const event = events.find(
        (e: any) => e.name === "Claimed" && equal(e.args.PacketId, packetId) && equal(e.args.claimer, claimer)
    );
    console.log(event);
    return event?.args.amount;
}

async function main() {
  const receipt = await ethers.provider.getTransactionReceipt("0x7066fc6b0ce1878af40361d4744c8d42cb5380c4388ca612647551d0197dffb0");
  console.log(await parseClaimed(receipt, "0x67a8130610178b3d3fd1d6824000df26d878243e41e58e29173afdbd4d5f1cb4", "0xBFdfEd0022848a6eF076dB2624737C08F5A42171"));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});