const { ethers } = require("hardhat");
const { utils, BigNumber } = require("ethers");
const hre = require("hardhat");
const AddressZero = "0x0000000000000000000000000000000000000000";

// Constants
const sleep = (delay) => new Promise((resolve) => setTimeout(resolve, delay));
const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);
const OAO = "0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0";

// Contract Variables
let reserve;

/*===================================================================*/
/*===========================  CONTRACT DATA  =======================*/

async function getContracts() {
  console.log("Retrieving Contracts");
  reserve = await ethers.getContractAt(
    "contracts/AiReserve.sol:AiReserve",
    "0x7F78a39E9414f89abE94ED40b992D0101857Babb"
  );
  console.log("Contracts Retrieved");
}

/*===========================  END CONTRACT DATA  ===================*/
/*===================================================================*/

async function deployReserve() {
  console.log("Starting Reserve Deployment");
  const reserveArtifact = await ethers.getContractFactory("AiReserve");
  const reserveContract = await reserveArtifact.deploy(OAO, {
    gasPrice: ethers.gasPrice,
  });
  reserve = await reserveContract.deployed();
  await sleep(5000);
  console.log("Reserve Deployed at:", reserve.address);
}

async function printDeployment() {
  console.log("**************************************************************");
  console.log("Reserve: ", reserve.address);
  console.log("**************************************************************");
}

async function verifyReserve() {
  console.log("Starting Reserve Verification");
  await hre.run("verify:verify", {
    address: reserve.address,
    contract: "contracts/AiReserve.sol:AiReserve",
    constructorArguments: [OAO],
  });
  console.log("Reserve Verified");
}

async function main() {
  const [wallet] = await ethers.getSigners();
  console.log("Using wallet: ", wallet.address);

  await getContracts();

  //===================================================================
  // 1. Deploy System
  //===================================================================

  // console.log("Starting System Deployment");
  // await deployReserve();
  // await printDeployment();

  /*********** UPDATE getContracts() with new addresses *************/

  //===================================================================
  // 2. Verify System
  //===================================================================

  // console.log("Starting Verification");
  // await verifyReserve();

  //===================================================================
  // 4. Transactions
  //===================================================================

  console.log("Starting Transactions");

  // let fee = await reserve.estimateFee(11);
  // console.log("Fee: ", fee);

  // await reserve.connect(wallet).calculateAIResult(11, "Hello World", {
  //   value: "10000000000000000",
  //   gasLimit: "1000000",
  // });

  // let result = await reserve.connect(wallet).getAIResult(11, "Hello World");
  // console.log("Result: ", result);

  console.log("Transaction Sent");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
