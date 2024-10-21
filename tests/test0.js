const convert = (amount, decimals) => ethers.utils.parseUnits(amount, decimals);
const divDec = (amount, decimals = 18) => amount / 10 ** decimals;
const divDec6 = (amount, decimals = 6) => amount / 10 ** decimals;
const { expect } = require("chai");
const { ethers, network } = require("hardhat");
const { execPath } = require("process");

const AddressZero = "0x0000000000000000000000000000000000000000";
const one = convert("1", 18);
const two = convert("2", 18);
const five = convert("5", 18);
const oneHundred = convert("100", 18);

let owner, user0, user1, user2;
let aiReserve;

describe("local: test0", function () {
  before("Initial set up", async function () {
    console.log("Begin Initialization");

    [owner, user0, user1, user2] = await ethers.getSigners();

    const aiReserveArtifact = await ethers.getContractFactory("AiReserve");
    aiReserve = await aiReserveArtifact.deploy(
      "0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0"
    ); // OAO Proxy on ETH Sepolia
    console.log("- AI Reserve Initialized");

    console.log("Initialization Complete");
    console.log();
  });

  it("First Test", async function () {
    console.log("******************************************************");
  });
});
