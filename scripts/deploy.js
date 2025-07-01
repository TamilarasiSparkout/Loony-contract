const { ethers, upgrades} = require("hardhat");
// const hre = require("hardhat");
require('@openzeppelin/hardhat-upgrades');

async function main() {

//     // LOONY token contract
//     const [deployer] = await ethers.getSigners();
//     console.log("Deploying contracts with account:", deployer.address);

//     const LoonyToken = await ethers.getContractFactory("LoonyToken");

//     const loonyToken = await upgrades.deployProxy(LoonyToken, [], {
//         initializer: "initialize",
//     });

//     await loonyToken.waitForDeployment();

//     console.log("LoonyToken deployed to:", await loonyToken.getAddress());
// }







//   USDT Token Contract deplopyment

// const [deployer] = await hre.ethers.getSigners();
// console.log("Deploying USDT contract with account:", deployer.address);

//     const USDT = await hre.ethers.getContractFactory("USDT");
//     const usdt = await USDT.deploy();

//     const USDTAddress = await usdt.getAddress();
//     console.log("USDT deployed to:", USDTAddress);

// }
  






//  //Get the vesting contract factory
//   const Vesting = await ethers.getContractFactory("Vesting");

//   // Deploy proxy with UUPS upgradeability
//   const vestingProxy = await upgrades.deployProxy(
//     Vesting,
//     ["0x356C03F793a1d46dFD6bb84c0a94fBd558e4a427"], // Pass constructor/initializer params (sandtoken)
//     {
//       initializer: "initialize", // Name of the initializer function
//       kind: "uups",
//     }
//   );

//   await vestingProxy.waitForDeployment();
//   console.log("Vesting contract deployed to:", await vestingProxy.getAddress());

// }





    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);

    const rate = 50; // Example: 1 USDT = 50 Loony (token price = $0.02)
    const openingTime = Math.floor(Date.now() / 1000) + 60; // 1 min from now
    const closingTime = openingTime + 7 * 24 * 60 * 60; // 7 days later

    // Replace with actual deployed addresses
    const LoonyTokenAddress = "0x356C03F793a1d46dFD6bb84c0a94fBd558e4a427";
    const usdtTokenAddress = "0xCA7727C70AD81595a2741cFeE7277b5F7e3f6e09";
    const vestingAddress = "0x32bc865b9A846bea2d8AD644461cB73E4Bb8bFD8";

    const CrowdSale = await ethers.getContractFactory("CrowdSale");

    const crowdSale = await upgrades.deployProxy(
        CrowdSale,
        [
            rate,
            LoonyTokenAddress,
            usdtTokenAddress,
            openingTime,
            closingTime,
            vestingAddress,
        ],
        {
            initializer: "initialize",
        }
    );

    await crowdSale.waitForDeployment();

    console.log("CrowdSale Contract deployed to:", await crowdSale.getAddress());

    //Set tax rates

    const buyTax = 300;  // 3%
    const tx = await crowdSale.setTaxRates(buyTax);
    await tx.wait();
    console.log(" Tax rates set successfully.");
    
}


main().catch((error) => {
console.error(error);
process.exitCode = 1;
});
