const { network, ethers } = require("hardhat");
const { networkConfig, developmentChains, VERIFICATION_BLOCK_CONFIRMATIONS } = require("../helper-hardhat-config");
const { verify } = require("../utils/verify");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = network.config.chainId;
  let vrfCoordinatorV2Address, subscriptionId, vrfCoordinatorV2Mock;
  if (chainId == 31337) {
    vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
    vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address;
    const txResponse = await vrfCoordinatorV2Mock.createSubscription();
    const txReceipt = await txResponse.wait();
    subscriptionId = txReceipt.events[0].args.subId;
    await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, ethers.utils.parseEther("1"));
  } else {
    vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"];
    subscriptionId = networkConfig[chainId]["subscriptionId"];
  }

  const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : VERIFICATION_BLOCK_CONFIRMATIONS;

  log("---------------------------");
  const args = [
    subscriptionId,
    vrfCoordinatorV2Address,
    networkConfig[chainId]["gasLane"],
    networkConfig[chainId]["callbackGasLimit"],
  ];

  const warrior721Contract = await deploy("Warrior721", {
    from: deployer,
    args: args,
    log: true,
    waitBlockConfirmations: waitBlockConfirmations,
  });

  if (developmentChains.includes(network.name)) {
    const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock");
    await vrfCoordinatorV2Mock.addSubscription(subscriptionId, warrior721Contract.address);
  }

  if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
    log("Verifying..");
    await verify(warrior721Contract.address, args);
  }
};

module.exports.tags = ["all", "warrior721"];
