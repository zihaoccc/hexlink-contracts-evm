import {expect} from "chai";
import {ethers, deployments, artifacts} from "hardhat";

const sender = "mailto:sender@gmail.com";
const receiver = "mailto:receiver@gmail.com";

const getContract = async function(name: string) {
  const deployment = await deployments.get(name);
  return await ethers.getContractAt(name, deployment.address);
};

describe("IdentityOracle", function() {
  beforeEach(async function() {
    const { validator } = await getNamedAccounts();
    await deployments.fixture(["TEST"]);
    const [emailOtp, twitterOAuth] = await hre.run("init_oracle", {});
    await hre.run(
        "register_validator",
        {oracle: emailOtp, validator: validator.address}
    );
    await hre.run(
        "register_validator",
        {oracle: twitterOAuth, validator: validator.address}
    );
  });

  it("validator should be registered", async function() {
    const { validator } = await getNamedAccounts();
    const registry = await getContract("IdentityOracleRegistry");

    const emailOtp = await ethers.getContractAt(
        "SimpleIdentityOracle",
        await registry.oracle({identityType: 1, authType: 1})
    );
    expect(
        await emailOtp.isRegistered(validator.address)
    ).to.be.true;

    const twitterOAuth = await ethers.getContractAt(
        "SimpleIdentityOracle",
        await registry.oracle({identityType: 4, authType: 2})
    );
    expect(
        await twitterOAuth.isRegistered(validator.address)
    ).to.be.true;
  });

  it("signature check", async function() {
    const { validator } = await getNamedAccounts();
    const registry = await getContract("IdentityOracleRegistry");
    const oracle = await ethers.getContractAt(
        "IERC1721",
        await registry.oracle({identityType: 1, authType: 1})
    );

    const message = ethers.utils.keccak256("message");
    const signature = await validator.signMessage(message);
    const encodedSig = ethers.utils.defaultAbiCoder.encode(
        ["address", "bytes"],
        [validator.address, signature]
    );
    expect(
        await oracle.isValidSignature(encodedSig)
    ).to.eq(oracle.interface.getSigHash("isValidSignature"));
  });
});