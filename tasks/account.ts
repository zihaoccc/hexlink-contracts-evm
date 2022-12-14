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