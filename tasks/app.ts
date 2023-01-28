import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers, Contract } from "ethers";

const REDPACKET : {[key: string]: string} = {
    "goerli": "0xad7346eBfCd605A9528fCdFfe868e5d4772A3362",
    "mumbai": "0x71adadC8059160472e93A7DfEedDBf3c5752A6B4",
}

const getRedPacket = async function(
    hre: HardhatRuntimeEnvironment
): Promise<Contract> {
    let address = REDPACKET[hre.network.name];
    if (!address) {
        address = (await hre.deployments.get("HappyRedPacket")).address;
    }
    return await hre.ethers.getContractAt(
        "HappyRedPacketImpl",
        ethers.utils.getAddress(address)
    );
}

task("redpacket", "get contract address of redpacket")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
        return (await getRedPacket(hre)).address;
    });