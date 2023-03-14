const AlvinERC721 = artifacts.require("AlvinERC721");
const AlvinMarketplace = artifacts.require("AlvinMarketplace");
const AlvinERC1155 = artifacts.require("AlvinERC1155");

module.exports = async function (deployer) {
  const admin = "0x904128Cf73E4185f8dfc5087FCD9B63081027Cf6";
  // const contractFactoryInstance = await AlvinMarketplace.new(admin, admin);

  // const gasEstimate = await contractFactoryInstance.createInstance.estimateGas();
  // console.log("gasEstimate", gasEstimate);
  await deployer.deploy(AlvinMarketplace, admin, admin);
  const marketplace = await AlvinMarketplace.deployed();
  console.log("marketplace", marketplace.address);

  await deployer.deploy(AlvinERC721, marketplace.address);
  await deployer.deploy(AlvinERC1155, marketplace.address);
};

//721- 0x539e676Dde6984d96cd4f48a1a77C3A5adbfA482
// marketplace- 0x14050Dca617eC24653731f5E4009327a8100A8B9
