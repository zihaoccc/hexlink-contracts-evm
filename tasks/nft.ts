import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { ethers } from "ethers";

task("mint", "Mints from the NFT cxontract")
    .addParam("address", "The address to receive a token")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const contract = await hre.ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const tx = await contract.mintTo(args.address, {
        gasLimit: 500000,
      });
      console.log(`Transaction Hash: ${tx.hash}`);
    });

task("set-base-token-uri", "Sets the base token URI for the deployed smart contract")
    .addParam("baseUrl", "The base of the tokenURI endpoint to set")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const contract = await hre.ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const tx = await contract.setBaseTokenURI(args.baseUrl, {
        gasLimit: 500000,
      });
      console.log(`Transaction Hash: ${tx.hash}`);
    });

task("token-uri", "Fetches the token metadata for the given token ID")
    .addParam("tokenId", "The tokenID to fetch metadata for")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const contract = await hre.ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const metadata_url = await contract.tokenURI(args.tokenId, {
        gasLimit: 500000,
      });
      console.log(`Metadata URL: ${metadata_url}`);
      const metadata = await fetch(metadata_url).then(res => res.json());
      console.log(`Metadata fetch response: ${JSON.stringify(metadata, null, 2)}`);
    });

task("sendNFT", "send NFT")
    .addParam("sender", "sender email")
    .addParam("receiver", "receiver email")
    .addParam("collection", "collection address")
    .addParam("id", "token ID")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
      const [deployer] = await hre.ethers.getSigners();
      const sender = await hre.run("account", args.sender);
      const receiver = await hre.run("account", args.receiver);

      const account = await hre.ethers.getContractAt("IAccount", sender);
      const artifact = await hre.artifacts.readArtifact("ERC721");
      const iface = new ethers.utils.Interface(artifact.abi);
      const txData = iface.encodeFunctionData(
          "transferFrom",
          [sender, receiver, args.token_id]
      );
      const tx = await account.connect(deployer).exec({
        to: args.collection,
        value: 0,
        callData: txData,
        callGasLimit: 0
      });
      return tx.hash;
    });
