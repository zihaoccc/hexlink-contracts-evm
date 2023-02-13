
import { ethers, run } from "hardhat";

async function main() {
    const data = "0x43cdffe000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000002000000000000000000000000019c80d80f62ac167cc86e0f7500222d33e18f15d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c4b510391f000000000000000000000000871d84ee4cbc8e2e51ec43aa4a85cc88c1627aa200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000041ec559f04d060ad595d5085b2eff2abf310b86c1d44ef68b0bf1e1de4a3487da324efe6738ca935f9199e870c13c2b6ae9d4176904f6d630ffa2390e90592e5411b0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    const hexlink : ethers.Contact = await run("hexlink", {});
    const decoded = hexlink.interface.decodeFunctionData("process", data);
    const callData = decoded.ops[0].callData;
    const erc721 : ethers.Contact = await ethers.getContractAt(
        "HexlinkErc721", decoded.ops[0].to
    );
    const mintData = erc721.interface.decodeFunctionData("mint", callData);
    console.log(mintData);
    const message = ethers.utils.keccak256(
        ethers.utils.defaultAbiCoder.encode(
            ["uint256", "address", "address"],
            [5, erc721.address, mintData.recipient]
        )
    );
    const validator = new ethers.Wallet(process.env.HARDHAT_VALIDATOR);
    const signature = await validator.signMessage(ethers.utils.arrayify(message));

    console.log(validator.address);
    console.log(await erc721.validator());

    console.log(signature);
    console.log(mintData.signature);
    console.log(signature === mintData.signature);

    const { deployer } = await ethers.getNamedSigners();
    const tx = await erc721.connect(deployer).mint(mintData.recipient, mintData.signature);
    console.log(tx.hash);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});