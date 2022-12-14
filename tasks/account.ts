import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import { ethers, BigNumber } from "ethers";

interface UserOp {
  to: string;
  value: BigNumber;
  callData: string | [];
  callGasLimit: Number;
}

const genERC20TransferTxData = async function(
  hre: HardhatRuntimeEnvironment,
  receiver: string,
  amount: string
): Promise<string> {
  const artifact = await hre.artifacts.readArtifact("ERC20");
  const iface = new ethers.utils.Interface(artifact.abi);
  return iface.encodeFunctionData(
      "transfer",
      [receiver, ethers.utils.parseEther(amount)]
  );
}

task("send", "send ETH or token")
    .addParam("sender", "sender name")
    .addParam("receiver", "receiver name")
    .addOptionalParam("token", "token contract address, use ETH if not set")
    .addParam("amount", "amount of ETH to send")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
      const { deployer } = await hre.getNamedAccounts();
      const sender = await hre.run("account", args.sender);
      const receiver = await hre.run("account", args.receiver);
      const account = await hre.ethers.getContractAt("IAccount", sender);
  
      let op : UserOp;
      if (args.token) {
        op = {
          to: args.token,
          value: BigNumber.from(0),
          callData: await genERC20TransferTxData(
            hre, receiver, args.amount
          ),
          callGasLimit: 0
        }
      } else {
        op = {
          to: receiver,
          value: ethers.utils.parseEther(args.amount),
          callData: [],
          callGasLimit: 0
        }
      }
      const tx = await account.connect(deployer).exec(op);
      return tx.hash;
    });

task("exec", "execute abiratry transaction")
    .addParam("account", "account address to exectute")
    .addParam("to")
    .addParam("value")
    .addParam("callData")
    .addOptionalParam("gasLimit")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
      const { deployer } = await hre.getNamedAccounts();
      const account = await hre.ethers.getContractAt(
          "IAccount",
          ethers.utils.getAddress(args.account)
      );
      const tx = await account.connect(deployer).exec({
        to: args.to,
        value: args.value || BigNumber.from(0),
        callData: args.callData,
        callGasLimit: args.gasLimit || 0
      });
      return tx.hash;
    });

task("mint", "Mints from the NFT cxontract")
    .addParam("address", "The address to receive a token")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const contract = await hre.ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const transactionResponse = await contract.mintTo(args.address, {
        gasLimit: 500000,
      });
      console.log(`Transaction Hash: ${transactionResponse.hash}`);
    });

task("set-base-token-uri", "Sets the base token URI for the deployed smart contract")
    .addParam("baseUrl", "The base of the tokenURI endpoint to set")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const {ethers} = hre;
      const contract = await ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const transactionResponse = await contract.setBaseTokenURI(args.baseUrl, {
        gasLimit: 500000,
      });
      console.log(`Transaction Hash: ${transactionResponse.hash}`);
    });

task("token-uri", "Fetches the token metadata for the given token ID")
    .addParam("tokenId", "The tokenID to fetch metadata for")
    .setAction(async function (args, hre: HardhatRuntimeEnvironment) {
      const {ethers} = hre;
      const contract = await ethers.getContractAt(
        "HexlinkNFT",
        "0x5FcbC0DD3ff625E64b9cC4337641e4861a1e791E",
      );
      const response = await contract.tokenURI(args.tokenId, {
        gasLimit: 500000,
      });
        
      const metadata_url = response;
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
      const {ethers} = hre;
      const [deployer] = await ethers.getSigners();
      const sender = await hre.run("account", args.sender);
      const receiver = await hre.run("account", args.receiver);

      const account = await ethers.getContractAt("IAccount", sender);
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
