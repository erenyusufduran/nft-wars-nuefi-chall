const { ethers } = require("hardhat");

const networkConfig = {
  default: {
    name: "hardhat",
  },
  31337: {
    name: "localhost",
    subscriptionId: "588",
    gasLane: "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc", // 30 gwei
    fightFee: ethers.utils.parseEther("0.01"), // 0.01 ETH
    mintFee: ethers.utils.parseEther("0.02"), // 0.01 ETH
    callbackGasLimit: "500000", // 500,000 gas
  },
  5: {
    name: "goerli",
    subscriptionId: "5794",
    gasLane: "0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15",
    fightFee: ethers.utils.parseEther("0.01"), // 0.01 ETH
    mintFee: ethers.utils.parseEther("0.02"), // 0.01 ETH
    callbackGasLimit: "500000", // 500,000 gas
    vrfCoordinatorV2: "0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D",
  },
  43113: {
    name: "cChain",
    subscriptionId: "470",
    gasLane: "0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61",
    fightFee: ethers.utils.parseEther("0.01"), // 0.01 ETH
    mintFee: ethers.utils.parseEther("0.02"), // 0.01 ETH
    callbackGasLimit: "500000", // 500,000 gas
    vrfCoordinatorV2: "0x2eD832Ba664535e5886b75D64C46EB9a228C2610",
  },
  80001: {
    name: "mumbai",
    subscriptionId: "2444",
    gasLane: "0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f",
    fightFee: ethers.utils.parseEther("0.01"), // 0.01 ETH
    mintFee: ethers.utils.parseEther("0.02"), // 0.01 ETH
    callbackGasLimit: "500000", // 500,000 gas
    vrfCoordinatorV2: "0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed",
  },
};

const developmentChains = ["hardhat", "localhost"];
const VERIFICATION_BLOCK_CONFIRMATIONS = 6;

module.exports = { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS };
