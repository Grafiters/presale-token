const { ethers } = require("hardhat");

async function main() {
    // This is just a convenience check
    if (network.name === "hardhat") {
      console.warn(
        "You are trying to deploy a contract to the Hardhat Network, which" +
          "gets automatically created and destroyed every time. Use the Hardhat" +
          " option '--network localhost'"
      );
    }
  
    // ethers is avaialble in the global scope
    const [deployer] = await ethers.getSigners();
    console.log(
      "Deploying the contracts with the account:",
      await deployer.getAddress()
    );
  
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // Deploy LaunchpadDEX contract
    const LaunchpadDEX = await ethers.getContractFactory("LaunchpadFactory");
    const launchpadDEX = await LaunchpadDEX.deploy();

    console.log("LaunchpadDEX deployed to:", launchpadDEX.address);
  }
  

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
