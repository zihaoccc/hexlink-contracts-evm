import {expect} from "chai";
import {ethers, deployments, artifacts, run} from "hardhat";
import { Contract } from "ethers";

const sender = "mailto:sender@gmail.com";
const receiver = "mailto:receiver@gmail.com";

const getContract = async function(name: string) : Promise<Contract> {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

describe("Hexlink Account", function() {
  beforeEach(async function() {
    const { deployer } = await ethers.getNamedSigners();
    await deployments.fixture(["ACCOUNT", "TEST"]);
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
    const { deployer } = await ethers.getNamedSigners();
    const impl = await getContract("AccountSimple");
    const beacon = await getContract("AccountBeacon");
    const proxy = await getContract("AccountProxy");

    expect(await beacon.implementation()).to.eq(impl.address);
    expect(await proxy.beacon()).to.eq(beacon.address);
  
    const impl2 = await getContract("AccountERC4337");
    await beacon.connect(deployer).upgradeTo(impl2.address);
    expect(await beacon.implementation()).to.eq(impl2.address);
    expect(await proxy.beacon()).to.eq(beacon.address);
  });

  it("Should transfer erc20 successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const proxy = await getContract("AccountProxy");
    const accountDeployer = await getContract("TestAccountDeployer");
    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(sender));
    const accountAddr = await accountDeployer.addressOfName(salt);

    // receive tokens before account created
    const token = await getContract("HexlinkToken");
    await expect(
      token.connect(deployer).transfer(accountAddr, 5000)
    ).to.emit(token, "Transfer")
      .withArgs(deployer.address, accountAddr, 5000);
    expect(await token.balanceOf(accountAddr)).to.eq(5000);

    // deploy account contract
    await expect(
      accountDeployer.deploy(salt)
    ).to.emit(accountDeployer, "Deploy").withArgs(accountAddr);
    const account = await ethers.getContractAt(
      "AccountSimple",
      accountAddr
    );
    await account.init(deployer.address);

    // receive tokens after account created
    await expect(
      token.connect(deployer).transfer(account.address, 5000)
    ).to.emit(token, "Transfer")
      .withArgs(deployer.address, account.address, 5000);
    expect(await token.balanceOf(account.address)).to.eq(10000);

    // send tokens
    expect(await token.balanceOf(account.address)).to.eq(10000);
    await run("send", {
      sender,
      receiver,
      token: token.address,
      hexlink: accountDeployer.address,
      amount: "5000"
    });
    expect(await token.balanceOf(account.address)).to.eq(5000);
  });

  it("Should transfer eth successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const proxy = await getContract("AccountProxy");
    const accountDeployer = await getContract("TestAccountDeployer");
    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(sender));
    const senderAddr = await accountDeployer.addressOfName(salt);

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
    await expect(
      accountDeployer.deploy(salt)
    ).to.emit(accountDeployer, "Deploy").withArgs(senderAddr);
    const account = await ethers.getContractAt(
      "AccountSimple",
      senderAddr
    );
    await account.init(deployer.address);

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
      sender,
      receiver,
      hexlink: accountDeployer.address,
      amount: ethers.utils.parseEther("0.5").toHexString()
    });
    const receiverAddr = await accountDeployer.addressOfName(
      ethers.utils.keccak256(ethers.utils.toUtf8Bytes(receiver))
    );
    expect(
      await ethers.provider.getBalance(receiverAddr)
    ).to.eq(ethers.utils.parseEther("0.5").toHexString());
  });

  it("Should hold and transfer ERC1155 successfully", async function() {
    const { deployer } = await ethers.getNamedSigners();
    const erc1155 = await getContract("TestHexlinkERC1155");

    const proxy = await getContract("AccountProxy");
    const accountDeployer = await getContract("TestAccountDeployer");
    const salt = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(sender));
    const senderAddr = await accountDeployer.addressOfName(salt);

    // receive erc1155 before account created
    await expect(
      erc1155.connect(deployer).safeTransferFrom(
        deployer.address, senderAddr, 1, 10, []
      )
    ).to.emit(erc1155, "TransferSingle")
      .withArgs(deployer.address, deployer.address, senderAddr, 1, 10);
    expect(await erc1155.balanceOf(senderAddr, 1)).to.eq(10);

    // create new account contract
    await expect(
      accountDeployer.deploy(salt)
    ).to.emit(accountDeployer, "Deploy").withArgs(senderAddr);
    const account = await ethers.getContractAt(
      "AccountSimple",
      senderAddr
    );
    await account.init(deployer.address);

    // receive erc1155 with contract
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

});
