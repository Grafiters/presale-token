const { expect } = require("chai");
const { ethers } = require("hardhat");

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

describe("LaunchpadDEX", function () {
  let owner, addr1, addr2;
  let token, paymentToken, launchpad;
  let rate, startTime, endTime, hardCap;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy mock ERC20 tokens
    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    const tokenDeploy = await ERC20.deploy("Token", "TKN", ethers.parseEther("1000000"));
    await tokenDeploy.waitForDeployment();
    token = tokenDeploy;

    const paymentTokenDeploy = await ERC20.deploy("PaymentToken", "PAY", ethers.parseEther("1000000"));
    await paymentTokenDeploy.waitForDeployment();
    paymentToken = paymentTokenDeploy;

    // Deploy LaunchpadDEX
    const LaunchpadDEX = await ethers.getContractFactory("LaunchpadDEX");
    launchpad = await LaunchpadDEX.deploy();
    await launchpad.waitForDeployment();
    
    console.log("Launchpad Address:", await launchpad.getAddress());

    // Set presale parameters
    rate = ethers.parseUnits("0.1", 18);
    hardCap = ethers.parseUnits("10000", 18);
    
    const currentBlock = await ethers.provider.getBlock("latest");
    startTime = currentBlock.timestamp + 0; // 1 minute from now
    endTime = startTime + 3600; // 1 hour later
  });

  it("Should create a presale", async function () {
    await launchpad.createPresale(
      await token.getAddress(),
      await paymentToken.getAddress(),
      rate,
      startTime,
      endTime,
      hardCap
    );
    console.log(`create presale done`);

    const presale = await launchpad.presales(await token.getAddress());

    expect(presale.token).to.equal(await token.getAddress());
    expect(presale.rate).to.equal(rate);
    expect(presale.hardCap).to.equal(hardCap);
  });

  it("Should allow users to buy tokens", async function () {
    await launchpad.createPresale(
      await token.getAddress(),
      await paymentToken.getAddress(),
      rate,
      startTime,
      endTime,
      hardCap
    );

    await paymentToken.transfer(addr1.address, ethers.parseEther("10"));
    await paymentToken.connect(addr1).approve(await launchpad.getAddress(), ethers.parseEther("10"));

    this.timeout(120000)

    // Increase time and mine a block
    // await network.provider.send("evm_setNextBlockTimestamp", [startTime + 120]);
    // await network.provider.send("evm_mine");

    await launchpad.connect(addr1).buyToken(await token.getAddress(), ethers.parseEther("1"));

    const presale = await launchpad.presales(await token.getAddress());
    expect(presale.totalRaised).to.equal(ethers.parseEther("1"));
  });

//   it("Should allow presale creator to withdraw funds", async function () {
//     await launchpad.createPresale(
//       token.address,
//       paymentToken.address,
//       rate,
//       startTime,
//       endTime,
//       hardCap
//     );

//     await paymentToken.transfer(addr1.address, ethers.parseEther("10"));
//     await paymentToken.connect(addr1).approve(launchpad.address, ethers.parseEther("10"));

//     await ethers.provider.send("evm_increaseTime", [60]);
//     await ethers.provider.send("evm_mine");

//     await launchpad.connect(addr1).buyToken(token.address, ethers.parseEther("1"));
//     await ethers.provider.send("evm_increaseTime", [3600]);
//     await ethers.provider.send("evm_mine");

//     await launchpad.connect(owner).endPresale(token.address);
//     await launchpad.connect(owner).withdrawFunds(token.address);
//   });

//   it("Should return all presales", async function () {
//     await launchpad.createPresale(
//       token.address,
//       paymentToken.address,
//       rate,
//       startTime,
//       endTime,
//       hardCap
//     );

//     const presales = await launchpad.getAllPresales();
//     expect(presales.length).to.equal(1);
//     expect(presales[0].token).to.equal(token.address);
//   });
});
