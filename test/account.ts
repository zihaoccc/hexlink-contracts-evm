import { expect } from "chai";
import { ethers, deployments, run } from "hardhat";
import { Contract } from "ethers";

const namehash = function(name: string) : string {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
}
const senderName = "mailto:sender@gmail.com";
const sender = namehash(senderName);
const receiverName = "mailto:receiver@gmail.com";
const receiver = namehash(receiverName);

const getContract = async function(name: string) : Promise<Contract> {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

const deployAccount = async function(
  name: string,
  accountDeployer: Contract
) : Promise<Contract> {
  const { deployer } = await ethers.getNamedSigners();
  const artifact = await deployments.getArtifact("AccountSimple");
  const iface = new ethers.utils.Interface(artifact.abi);
  const data = iface.encodeFunctionData(
    "init", [deployer.address]
  );
  const accountAddr = await accountDeployer.addressOfName(name);
  await expect(
    accountDeployer.deploy(name, data)
  ).to.emit(accountDeployer, "Deploy").withArgs(accountAddr);
  return await ethers.getContractAt(
    "AccountSimple",
    accountAddr
  );
}

describe("Hexlink Account", function() {
  beforeEach(async function() {
    const { deployer } = await ethers.getNamedSigners();
    await deployments.fixture(["ADMIN", "ACCOUNT", "TEST"]);
    const proxy = await getContract("AccountProxy");
    // deploy test deployer
    await deployments.deploy("TestAccountDeployer", {
      from: deployer.address,
      args: [proxy.address],
      log: true,
      autoMine: true,
    });
    // deploy erc4337 implementation 
    await deployments.deploy("AccountERC4337", {
      from: deployer.address,
      args: [],
      log: true,
      autoMine: true,
    });
  });

  it("Should with correct beacon and implementation", async function() {
    const impl = await getContract("AccountSimple");
    const beacon = await getContract("AccountBeacon");
    const proxy = await getContract("AccountProxy");

    expect(await beacon.implementation()).to.eq(impl.address);
    expect(await proxy.beacon()).to.eq(beacon.address);
  
    const impl2 = await getContract("AccountERC4337");
    const data = beacon.interface.encodeFunctionData(
      "upgradeTo", [impl2.address]
    );
    await run("admin_exec", {target: beacon.address, data})
    expect(await beacon.implementation()).to.eq(impl2.address);
    expect(await proxy.beacon()).to.eq(beacon.address);
  });

  it("Should transfer erc20 successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const accountDeployer = await getContract("TestAccountDeployer");
    const accountAddr = await accountDeployer.addressOfName(sender);

    // receive tokens before account created
    const token = await getContract("HexlinkToken");
    await expect(
      token.connect(deployer).transfer(accountAddr, 5000)
    ).to.emit(token, "Transfer")
      .withArgs(deployer.address, accountAddr, 5000);
    expect(await token.balanceOf(accountAddr)).to.eq(5000);

    // deploy account contract
    const account = await deployAccount(sender, accountDeployer);

    // receive tokens after account created
    await expect(
      token.connect(deployer).transfer(account.address, 5000)
    ).to.emit(token, "Transfer")
      .withArgs(deployer.address, account.address, 5000);
    expect(await token.balanceOf(account.address)).to.eq(10000);

    // send tokens
    expect(await token.balanceOf(account.address)).to.eq(10000);
    await run("send", {
      sender: senderName,
      receiver: receiverName,
      token: token.address,
      hexlink: accountDeployer.address,
      amount: "5000"
    });
    expect(await token.balanceOf(account.address)).to.eq(5000);
  });

  it("Should transfer eth successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const accountDeployer = await getContract("TestAccountDeployer");
    const senderAddr = await accountDeployer.addressOfName(sender);

    // receive eth before account created
    const tx1 = await deployer.sendTransaction({
      to: senderAddr,
      value: ethers.utils.parseEther("1.0")
    });
    await tx1.wait();
    expect(
      await ethers.provider.getBalance(senderAddr)
    ).to.eq(ethers.utils.parseEther("1.0"));

    // create new account contract
    const account = await deployAccount(sender, accountDeployer);

    // receive eth after account created
    const tx2 = await deployer.sendTransaction({
      to: senderAddr,
      value: ethers.utils.parseEther("1.0")
    });
    await tx2.wait();
    expect(
      await ethers.provider.getBalance(senderAddr)
    ).to.eq(ethers.utils.parseEther("2.0"));

    // send ETH
    await run("send", {
      sender: senderName,
      receiver: receiverName,
      hexlink: accountDeployer.address,
      amount: ethers.utils.parseEther("0.5").toHexString()
    });
    const receiverAddr = await accountDeployer.addressOfName(receiver);
    expect(
      await ethers.provider.getBalance(receiverAddr)
    ).to.eq(ethers.utils.parseEther("0.5").toHexString());
  });

  it("Should hold and transfer ERC1155 successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const accountDeployer = await getContract("TestAccountDeployer");
    const senderAddr = await accountDeployer.addressOfName(sender);
    const erc1155 = await getContract("TestHexlinkERC1155");

    // receive erc1155 before account created
    await expect(
      erc1155.connect(deployer).safeTransferFrom(
        deployer.address, senderAddr, 1, 10, []
      )
    ).to.emit(erc1155, "TransferSingle")
      .withArgs(deployer.address, deployer.address, senderAddr, 1, 10);
    expect(await erc1155.balanceOf(senderAddr, 1)).to.eq(10);

    // create new account contract
    const account = await deployAccount(sender, accountDeployer);

    // receive erc1155 after account created
    await expect(
      erc1155.connect(deployer).safeTransferFrom(
        deployer.address, senderAddr, 1, 10, []
      )
    ).to.emit(erc1155, "TransferSingle")
      .withArgs(deployer.address, deployer.address, senderAddr, 1, 10);
    expect(await erc1155.balanceOf(senderAddr, 1)).to.eq(20);
  
    // send erc1155
    const artifact = await deployments.getArtifact("TestHexlinkERC1155");
    const iface = new ethers.utils.Interface(artifact.abi);
    const txData = iface.encodeFunctionData(
        "safeTransferFrom",
        [senderAddr, deployer.address, 1, 10, []]
    );
    await run("exec", {
      account: account.address,
      to: erc1155.address,
      callData: txData,
      hexlink: accountDeployer.address
    });
    expect(await erc1155.balanceOf(senderAddr, 1)).to.eq(10);
  });

  it("Should pay gas with eth", async function() {
    const accountDeployer = await getContract("TestAccountDeployer");
    const account = await deployAccount(sender, accountDeployer);
    const token = await getContract("HexlinkToken");
    const { deployer, validator, tester } = await ethers.getNamedSigners();

    // send token to account
    await token.connect(deployer).transfer(account.address, 5000);
    // send eth to account
    let balance = ethers.utils.parseEther("1.0");
    await deployer.sendTransaction({
      to: account.address,
      value: balance
    });

    // token transfer with validateAndCall
    const tokenSendingData = token.interface.encodeFunctionData(
        "transfer",
        [tester.address, 100]
    );
    const data = account.interface.encodeFunctionData(
        "exec",
        [
          {
            to: token.address,
            value: 0,
            callData: tokenSendingData,
            callGasLimit: 0
          }
        ]
    );
    const receiverAddr = await accountDeployer.addressOfName(receiver);
    const gas = {
      token: ethers.constants.AddressZero,
      price: 0,
      base: 50000, // in react it's around 36000 for payment and event emitting
      core: 0,
      refundReceiver: receiverAddr,
    };
    const nonce = await account.nonce();
    const requestId = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes", "tuple(address, uint256, uint256, uint256, address payable)", "uint256"],
        [data, [gas.token, gas.price, gas.core, gas.base, gas.refundReceiver], nonce]
      ));
    const signature = await deployer.signMessage(
      ethers.utils.arrayify(requestId)
    );
    const tx = await account.connect(validator).validateAndCall(
      data, gas, nonce, signature
    );

    const receipt = await tx.wait();
    const events = receipt.logs.filter(
      log => log.address == account.address
    ).map((log: any) => account.interface.parseLog(log));
    const event = events.find((e: any) => e.name == "GasPayment");
    expect(event.args.request).to.eq(requestId);
    
    // check eth balance
    expect(
      await ethers.provider.getBalance(receiverAddr)
    ).to.eq(event.args.payment);
    expect(
      await ethers.provider.getBalance(account.address)
    ).to.eq(balance.sub(event.args.payment));
    // check token balance
    expect(await token.balanceOf(tester.address)).to.eq(100);
    expect(await token.balanceOf(account.address)).to.eq(4900);
  });

  it("Should pay gas with erc20", async function() {
    const accountDeployer = await getContract("TestAccountDeployer");
    const account = await deployAccount(sender, accountDeployer);
    const token = await getContract("HexlinkToken");
    const { deployer, validator, tester } = await ethers.getNamedSigners();

    // send token to account
    await token.connect(deployer).transfer(account.address, 200000);

    // token transfer with validateAndCall
    const tokenSendingData = token.interface.encodeFunctionData(
        "transfer",
        [tester.address, 100]
    );
    const data = account.interface.encodeFunctionData(
        "exec",
        [
          {
            to: token.address,
            value: 0,
            callData: tokenSendingData,
            callGasLimit: 0
          }
        ]
    );
    const receiverAddr = await accountDeployer.addressOfName(receiver);
    const gas = {
      token: token.address,
      price: 1,
      base: 50000, // in react it's around 36000 for payment and event emitting
      core: 0,
      refundReceiver: receiverAddr,
    };
    const nonce = await account.nonce();
    const requestId = ethers.utils.keccak256(
      ethers.utils.defaultAbiCoder.encode(
        ["bytes", "tuple(address, uint256, uint256, uint256, address payable)", "uint256"],
        [data, [gas.token, gas.price, gas.core, gas.base, gas.refundReceiver], nonce]
      ));
    const signature = await deployer.signMessage(
      ethers.utils.arrayify(requestId)
    );
    const tx = await account.connect(validator).validateAndCall(
      data, gas, nonce, signature
    );

    const receipt = await tx.wait();
    const events = receipt.logs.filter(
      log => log.address == account.address
    ).map((log: any) => account.interface.parseLog(log));
    const event = events.find((e: any) => e.name == "GasPayment");
    expect(event.args.request).to.eq(requestId);
    
    // check token balance
    expect(await token.balanceOf(receiverAddr)).to.eq(event.args.payment);
    expect(await token.balanceOf(account.address)).to.eq(
      200000 - 100 - event.args.payment.toNumber()
    );
  });
});
