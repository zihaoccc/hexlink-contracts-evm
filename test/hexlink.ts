import {expect} from "chai";
import {ethers, deployments, getNamedAccounts, artifacts, run} from "hardhat";

function hash(value: string) {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(value));
}

const sender = hash("mailto:sender@gmail.com");
const receiver = hash("mailto:receiver@gmail.com");

const address0 = ethers.constants.AddressZero;

const getHexlink = async function() {
  const deployment = await deployments.get("Hexlink");
  return await ethers.getContractAt("HexlinkUpgradeable", deployment.address);
};

const buildDeployAuthProof = async function(params: {
  name: string,
  data?: string,
  validator?: string,
  nonce?: string
}) {
  return await run("build_deploy_auth_proof", params)
}

const buildResetAuthProof = async function(params: {
  name: string,
  account: string,
  validator?: string,
  nonce?: string
}) {
  return await run("build_reset_auth_proof", params)
}

describe("Hexlink", function() {
  beforeEach(async function() {
    await deployments.fixture(["HEXL"]);
  });

  it("should deploy account contract without init", async function() {
    const hexlink = await getHexlink();
    const { deployer } = await ethers.getNamedSigners();
    const name = sender;
    const accountAddr = await hexlink.addressOfName(name);
    const authProof = await buildDeployAuthProof({name});

    await expect(
      hexlink.deploy(name, [], authProof)
    ).to.emit(hexlink, "Deploy").withArgs(
      name, accountAddr
    );
    expect(await ethers.provider.getCode(accountAddr)).to.not.eq("0x");

    const account = await ethers.getContractAt("AccountSimple", accountAddr);
    expect(await account.owner()).to.eq(address0);

    await account.init(deployer.address, []);
    expect(await account.owner()).to.eq(deployer.address);
  });

  it("should deploy account contract", async function() {
    const hexlink = await getHexlink();
    const { deployer, validator } = await ethers.getNamedSigners();
    const name = sender;
    const accountAddr = await hexlink.addressOfName(name);
    expect(await ethers.provider.getCode(accountAddr)).to.eq("0x");

    // build tx data
    const artifact = await artifacts.readArtifact("AccountSimple");
    const iface = new ethers.utils.Interface(artifact.abi);
    const data = iface.encodeFunctionData(
        "init", [deployer.address, []]
    );
  
    // deploy with wrong validator
    let invalidAuthProof = await buildDeployAuthProof({
      name,
      data,
      validator: "deployer"
    });
    await expect(
      hexlink.reset(name, validator.address, invalidAuthProof)
    ).to.be.revertedWith("IO002");
  
    // deploy with wrong nonce
    invalidAuthProof = await buildDeployAuthProof({
      name,
      data,
      validator: "validator",
      nonce: "1"
    });

    await expect(
      hexlink.reset(name, deployer.address, invalidAuthProof)
    ).to.be.revertedWith("IO003");
  
    // deploy with wrong tx data
    const validAuthProof = await buildDeployAuthProof({
      name,
      data,
      validator: "validator",
    });
    await expect(
      hexlink.deploy(name, [], validAuthProof)
    ).to.be.revertedWith("IO003");

    // deploy with wrong name
    await expect(
      hexlink.deploy(receiver, data, validAuthProof)
    ).to.be.revertedWith("IO003");

    // deploy with wrong identity type without oracle
    invalidAuthProof = {
      ...validAuthProof,
      identityType: hash("twitter.com")
    };
    await expect(
      hexlink.deploy(name, data, invalidAuthProof)
    ).to.be.revertedWith("HEXL017");

    // deploy with wrong identity type and auth type
    invalidAuthProof = {
      ...validAuthProof,
      identityType: hash("twitter.com"),
      authType: hash("oauth")
    };
    await expect(
      hexlink.deploy(name, data, invalidAuthProof)
    ).to.be.revertedWith("IO003");
  
    //deploy account contract
    await expect(
      hexlink.deploy(name, data, validAuthProof)
    ).to.emit(hexlink, "Deploy").withArgs(
      name, accountAddr
    );
    expect(await ethers.provider.getCode(accountAddr)).to.not.eq("0x");

    // check owner
    const account = await ethers.getContractAt("AccountSimple", accountAddr);
    expect(await account.owner()).to.eq(deployer.address);

    // replay attack should throw
    await expect(hexlink.connect(deployer).deploy(name, data, validAuthProof))
      .to.be.revertedWith("IO003");

    // redeploy should throw
    const authProof2 = await buildDeployAuthProof({
      name,
      data,
      validator: "validator"
    });
    await expect(hexlink.connect(deployer).deploy(name, data, authProof2))
    .to.be.revertedWith("ERC1167: create2 failed");
    
    // reset after bootstrap should throw
    const authProof3 = await buildResetAuthProof({
      name,
      account: deployer.address,
      validator: "validator"
    });

    await expect(
      hexlink.reset(name, validator.address, authProof3)
    ).to.be.revertedWith("HEXL009");
  });

  it("Should reset account contract", async function() {
    const hexlink = await getHexlink();
    const name = sender;
    const { deployer, validator } = await ethers.getNamedSigners();
    const defaultAccount = await hexlink.addressOfName(name);

    // reset account contract to address(0)
    let validAuthProof = await buildResetAuthProof({
      name,
      account: address0,
      validator: "validator"
    });
    await expect(
      hexlink.reset(name, address0, validAuthProof)
    ).to.be.revertedWith("HEXL012");
  
    // reset with wrong validator
    let invalidAuthProof = await buildResetAuthProof({
      name,
      account: deployer.address,
      validator: "deployer"
    });
    await expect(
      hexlink.reset(name, validator.address, invalidAuthProof)
    ).to.be.revertedWith("IO002");
  
    // reset with wrong nonce
    invalidAuthProof = await buildResetAuthProof({
      name,
      account: deployer.address,
      validator: "validator",
      nonce: "1"
    });
    await expect(
      hexlink.reset(name, deployer.address, invalidAuthProof)
    ).to.be.revertedWith("IO003");
  
    // reset with wrong account
    validAuthProof = await buildResetAuthProof({
      name,
      account: deployer.address,
      validator: "validator",
    });
    await expect(
      hexlink.reset(name, validator.address, validAuthProof)
    ).to.be.revertedWith("IO003");

    // reset with wrong name
    await expect(
      hexlink.reset(receiver, deployer.address, validAuthProof)
    ).to.be.revertedWith("IO003");

    // reset with wrong identity type without oracle
    invalidAuthProof = {
      ...validAuthProof,
      identityType: hash("twitter.com")
    };
    await expect(
      hexlink.reset(receiver, deployer.address, invalidAuthProof)
    ).to.be.revertedWith("HEXL017");

    // reset with wrong identity/auth type
    invalidAuthProof = {
      ...validAuthProof,
      identityType: hash("twitter.com"),
      authType: hash("oauth")
    };
    await expect(
      hexlink.reset(receiver, deployer.address, invalidAuthProof)
    ).to.be.revertedWith("IO003");

    // reset account contract
    const nonce = await hexlink.nonce(name);
    await expect(
      hexlink.reset(name, deployer.address, validAuthProof)
    ).to.emit(hexlink, "Reset").withArgs(name, deployer.address);
    expect(await hexlink.addressOfName(name)).to.eq(deployer.address);
    expect(await hexlink.nonce(name)).to.eq(nonce.add(1));
  
    // replay attack should throw
    await expect(
      hexlink.reset(name, deployer.address, validAuthProof)
    ).to.be.revertedWith("HEXL009");
  
    // reset calls after bootstrap should throw
    const validAuthProof2 = await buildResetAuthProof({
      name,
      account: deployer.address,
      validator: "validator"
    });
    await expect(
      hexlink.reset(name, validator.address, validAuthProof2)
    ).to.be.revertedWith("HEXL009");

    // deploy should work
    const data = ethers.utils.defaultAbiCoder.encode(
      ["address"], [deployer.address]
    );
    const validAuthProof4 = await buildDeployAuthProof({
      name,
      data,
      validator: "validator",
    });
    await expect(
      hexlink.deploy(name, data, validAuthProof4)
    ).to.emit(hexlink, "Deploy").withArgs(name, defaultAccount);
  });

  it("Should upgrade", async function() {
    const hexlinkProxy = await deployments.get("Hexlink");
    const hexlinkV1 = await ethers.getContractAt(
      "HexlinkUpgradeable",
      hexlinkProxy.address
    );
    const hexlinkImpl = await deployments.get("HexlinkUpgradeable");
    expect(await hexlinkV1.implementation()).to.eq(hexlinkImpl.address);
    const senderAddr = await hexlinkV1.addressOfName(sender);

    // deploy new hexlink impl
    const accountProxy = await deployments.get("AccountProxy");
    const {deployer} = await getNamedAccounts();
    const newHexlinkImpl = await deployments.deploy("HexlinkUpgradeableV2ForTest", {
      from: deployer,
      args: [accountProxy.address],
      log: true,
      autoMine: true,
    });

    // upgrade
    const data = hexlinkV1.interface.encodeFunctionData(
      "upgradeTo",
      [newHexlinkImpl.address]
    );
    await run("admin_schedule_and_exec", {target: hexlinkV1.address, data});

    const hexlinkV2 = await ethers.getContractAt(
      "HexlinkUpgradeableV2ForTest",
      hexlinkProxy.address
    );
    expect(
      await hexlinkV2.implementation()
    ).to.eq(newHexlinkImpl.address);
    expect(
      await hexlinkV2.addressOfName(sender)
    ).to.eq(senderAddr);
    expect(
      await hexlinkV2.name()
    ).to.eq("HexlinkUpgradeableV2ForTest");
  });
});
