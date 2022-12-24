import {expect} from "chai";
import {ethers, deployments, artifacts, network, run} from "hardhat";
import { Contract, Signer } from "ethers";

const namehash = function(name: string) {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(name));
}
const sender = namehash("mailto:sender@gmail.com");
const receiver = namehash("mailto:receiver@gmail.com");

const idTypeEmail = 1;
const authTypeOtp = 1;

const getHexlink = async function() {
  const deployment = await deployments.get("HexlinkProxy");
  return await ethers.getContractAt("Hexlink", deployment.address);
};

const buildAuthProof = async function(
  name: string,
  funcSig: string,
  txData: Signer,
  validator: Signer,
  hexlink: Contract
) {
  const nonce = await hexlink.nonce(sender);
  const requestId = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes4", "bytes", "address", "uint256", "uint256"],
      [funcSig, txData, hexlink.address, network.config.chainId, nonce]
    )
  );
  const issuedAt = Math.round(Date.now() / 1000);
  const message = ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32", "uint256", "uint256", "uint256"],
      [sender, requestId, issuedAt, idTypeEmail, authTypeOtp]
    )
  );
  const signature = await validator.signMessage(message);
  const encodedSig = ethers.utils.defaultAbiCoder.encode(
    ["address", "bytes"], [validator.address, signature]
  )
  return {
    issuedAt,
    identityType: 1,
    authType: 1,
    signature: encodedSig
  };
}

const buildResetAuthProof = async function(
  name: string,
  account: string,
  validator: Signer,
  hexlink: Contract
) {
  const txData = ethers.utils.defaultAbiCoder.encode(
    ["address"], [account]
  );
  const funcSig = hexlink.artifact.interface.getSighash("reset");
  return await buildAuthProof(
    sender, funcSig, txData, validator, hexlink
  );
}

const buildDeployAuthProof = async function(
  name: string,
  txData: string,
  validator: Signer,
  hexlink: Contract
) {
  const funcSig = hexlink.interface.getSighash("deploy");
  return await buildAuthProof(
    sender, funcSig, txData, validator, hexlink
  );
}

describe("Hexlink", function() {
  beforeEach(async function() {
    await deployments.fixture(["HEXL"]);
    const { validator } = await getNamedAccounts();
    await run("init_oracle", {validator});
  });

  it.only("should deploy account contract", async function() {
    const hexlink = await getHexlink();
    const { deployer, validator } = await ethers.getNamedSigners();
    const accountAddr = await hexlink.addressOfName(sender);
    expect(await ethers.provider.getCode(accountAddr)).to.eq("0x");

    // sign auth proof
    const txData = ethers.utils.defaultAbiCoder.encode(
      ["address"], [deployer.address]
    );
    const authProof1 = await buildDeployAuthProof(
      sender, txData, validator, hexlink
    );

    // deploy account contract
    await expect(
      hexlink.deploy(sender, txData, authProof1)
    ).to.emit(hexlink, "Deploy").withArgs(
      sender, accountAddr
    );
    expect(await ethers.provider.getCode()).to.not.eq("0x");

    // check owner
    const account = await ethers.getContract("AccountSimple", accountAddr);
    expect(await account.owner()).to.eq(deployer.address);

    // replay attack should throw
    await expect(hexlink.connect(deployer).deploy(sender, txData, authProof1))
      .to.be.revertedWith("IO003");

    // redeploy should throw
    const authProof2 = await buildAuthProof(
      sender, txData, validator, hexlink
    );
    await expect(hexlink.connect(deployer).deploy(sender, txData, authProof2))
    .to.be.revertedWith("IO003");
    
    // reset after bootstrap should throw
    const authProof3 = await buildResetAuthProof(
      sender, deployer.address, validator, hexlink);
    await expect(
      hexlink.reset(sender, validator.address, authProof3)
    ).to.be.revertedWith("HEXL009");
  });

  it("Should reset account contract", async function() {
    const hexlink = await getHexlink();
    const { deployer, validator } = await ethers.getNamedSigners();
    const defaultAccount = await hexlink.addressOfName(sender);

    // sign invalid auth proof
    const authProof1 = await buildResetAuthProof(
      sender, ethers.constants.AddressZero, validator, hexlink);

    // reset account contract to address(0)
    await expect(
      hexlink.reset(sender, ethers.constants.AddressZero, authProof1)
    ).to.be.revertedWith("HEXL012");

    // sign valid auth proof
    const authProof2 = await buildResetAuthProof(
      sender, deployer.address, validator, hexlink);
    await hexlink.reset(sender, deployer.address, authProof1);
    expect(await hexlink.addressOfName(sender)).to.eq(deployer.address);
  
    // reset account contract
    const nonce = await hexlink.nonce(sender);
    await expect(
      hexlink.reset(sender, deployer.address, authProof1)
    ).to.emit(hexlink, "Reset").withArgs(sender, deployer.address);
    expect(await hexlink.addressOfName(sender)).to.eq(deployer.address);
    expect(await hexlink.nonce(sender)).to.eq(nonce.add(1));
  
    // replay attack should throw
    await expect(
      hexlink.reset(sender, deployer.address, authProof1)
    ).to.be.revertedWith("IO003");
  
    // reset calls after bootstrap should throw
    const authProof3 = await buildResetAuthProof(
      sender, deployer.address, validator, hexlink);
    await expect(
      hexlink.reset(sender, validator.address, authProof3)
    ).to.be.revertedWith("HEXL009");

    // deploy should work
    const txData = ethers.utils.defaultAbiCoder.encode(
      ["address"], [deployer.address]
    );
    const authProof4 = await buildDeployAuthProof(
      sender, txData, validator, hexlink
    );
    await expect(
      hexlink.deploy(sender, txData, authProof4)
    ).to.emit(hexlink, "Deploy").withArgs(name, defaultAccount);
  });
});
