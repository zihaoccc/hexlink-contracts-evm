import {expect} from "chai";
import {
  ethers,
  deployments,
  getNamedAccounts,
} from "hardhat";

function hash(value: string) {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(value));
}

const getContract = async function(name: string) {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

describe("IdentityOracle", function() {
  beforeEach(async function() {
      await deployments.fixture(["ADMIN", "ORACLE"]); 
  });

  it("validator should be registered", async function() {
    const { validator } = await getNamedAccounts();
    const registry = await getContract("IdentityOracleRegistry");

    const emailOtp = await ethers.getContractAt(
        "SimpleIdentityOracle",
        await registry.oracle({
          identityType: hash("email"),
          authType: hash("otp")
        })
    );
    expect(
        await emailOtp.isRegistered(validator)
    ).to.be.true;

    const twitterOAuth = await ethers.getContractAt(
        "SimpleIdentityOracle",
        await registry.oracle({
          identityType: hash("twitter.com"),
          authType: hash("oauth")
        })
    );
    expect(
        await twitterOAuth.isRegistered(validator)
    ).to.be.true;
  });

  it("signature check", async function() {
    const validator = await ethers.getNamedSigner("validator");
    const registry = await getContract("IdentityOracleRegistry");
    const oracle = await ethers.getContractAt(
        "IERC1271",
        await registry.oracle({
          identityType: hash("email"),
          authType: hash("otp")
        })
    );

    const message = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes("message")
    );
    const signature = await validator.signMessage(
        ethers.utils.arrayify(message)
    );
    const encodedSig = ethers.utils.defaultAbiCoder.encode(
        ["address", "bytes"],
        [validator.address, signature]
    );
    expect(
        await oracle.isValidSignature(message, encodedSig)
    ).to.eq(oracle.interface.getSighash("isValidSignature"));
  });
});