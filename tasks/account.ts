import {task} from "hardhat/config";
import {HardhatRuntimeEnvironment} from "hardhat/types";
import { ethers, BigNumber } from "ethers";

interface UserOp {
  to: string;
  value: BigNumber;
  callData: string | [];
  callGasLimit: BigNumber;
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
      [receiver, amount]
  );
}

task("send", "send ETH or token")
    .addParam("sender", "sender name")
    .addParam("receiver", "receiver name")
    .addOptionalParam("token", "token contract address, use ETH if not set")
    .addOptionalParam("hexlink", "the hexlink contract for addres look up")
    .addParam("amount", "amount of ETH/Token to send")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
      const { deployer } = await hre.ethers.getNamedSigners();
      const sender = await hre.run("account", {name: args.sender, hexlink: args.hexlink});
      const receiver = await hre.run("account", {name: args.receiver, hexlink: args.hexlink});
      const account = await hre.ethers.getContractAt("IAccount", sender);
  
      let op : UserOp;
      if (args.token) {
        op = {
          to: args.token,
          value: BigNumber.from(0),
          callData: await genERC20TransferTxData(
            hre, receiver, args.amount
          ),
          callGasLimit: BigNumber.from(0)
        }
      } else {
        op = {
          to: receiver,
          value: args.amount,
          callData: [],
          callGasLimit: BigNumber.from(0)
        }
      }
      const tx = await account.connect(deployer).exec(op);
      return tx.hash;
    });

task("exec", "execute abiratry transaction")
    .addParam("account", "account address to exectute")
    .addParam("to")
    .addParam("callData")
    .addOptionalParam("value")
    .addOptionalParam("gasLimit")
    .setAction(async (args, hre : HardhatRuntimeEnvironment) => {
      const { deployer } = await hre.ethers.getNamedSigners();
      const account = await hre.ethers.getContractAt(
          "IAccount",
          ethers.utils.getAddress(args.account)
      );
      const tx = await account.connect(deployer).exec({
        to: args.to,
        value: args.value || BigNumber.from(0),
        callData: args.callData,
        callGasLimit: args.gasLimit || BigNumber.from(0)
      });
      return tx.hash;
    });