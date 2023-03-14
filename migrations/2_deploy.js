// const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const ethers = require("ethers");
const EchoooERC721 = artifacts.require("EchoooERC721");
const EchoooERC1155 = artifacts.require("EchoooERC1155");
const EchoooMarketplace = artifacts.require("EchoooMarketplace");
const ERC721Delegate = artifacts.require("ERC721Delegate");
const ERC1155Delegate = artifacts.require("ERC1155Delegate");
const MOCK_WETH = artifacts.require("MockWETH");
const EchoooMulticall = artifacts.require("EchoooMulticall");

module.exports = async function (deployer, network, accounts) {
  const admin = "0xda9e61D4fa10bcC5f5429229Ca14668628D6AAea";

  // const instance = await deployProxy(AlvinMarketplace, { deployer });
  await deployer.deploy(EchoooMarketplace, admin);
  const marketplace = await EchoooMarketplace.deployed();
  await deployer.deploy(ERC721Delegate);
  await deployer.deploy(ERC1155Delegate);

  await deployer.deploy(
    EchoooERC721,
    marketplace.address,
    "http://localhost:400/token/"
  );
  await deployer.deploy(
    EchoooERC1155,
    marketplace.address,
    "http://localhost:400/token/"
  );
  await deployer.deploy(EchoooMulticall);
  await deployer.deploy(MOCK_WETH);
  const weth = await MOCK_WETH.deployed();
  await weth.mint(accounts[0], ethers.utils.parseUnits("10", "ether"));
  await weth.mint(accounts[1], ethers.utils.parseUnits("10", "ether"));
  await weth.mint(accounts[2], ethers.utils.parseUnits("10", "ether"));
  // await deployer.deploy(AlvinERC1155, marketplace.address);
};

//721- 0x18C68B3adacE08C934408c343BC50a7EDe3F4aD7
// 1155- 0xE4469AD25d7d00360b67f8F04228e829dcc90dDc
// marketplace- 0x6B885a91B85D57C130506E952C700c844Cc969c3
// 721 del- 0xdefD66186107b38B7070C99703AB71Ef98530B6B
// 1155 del - 0x634F538186e860e64F366452AA3eA3AFDb9e79ca
//weth- 0x738C632B25D40d99fCbC4603c85422bE170Bb2Cb
