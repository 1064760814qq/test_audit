const ethers = require("ethers");
const {
  admin,
  seller,
  buyer,
  erc721instance,
  erc1155instance,
  marketplaceinstance,
  erc721Delegate,
  erc1155Delegate,
} = require("./constant");

/**
 * create 721 token
 * royalty set to 0.1 (1000/10000)- 10000 FEE_DENOMINATOR
 */
const create721 = async (creator) => {
  const response = await erc721instance
    .connect(creator)
    .create(creator.address, 1000, "abc.com");
  console.log("tx hash: ", response.hash);
  const receipt = await response.wait();
  const _721tokenId = parseInt(receipt.logs[0].topics[3]);

  console.log("tokenId-", _721tokenId);
};

/**
 * approve 721Delegate address to allow transfers on basis of user
 */
const approve721DelegateContract = async (creator) => {
  const response = await erc721instance
    .connect(creator)
    .setApprovalForAll(erc721Delegate.address, true);
  console.log("tx hash: ", response.hash);
  await response.wait();
  console.log("confirmed");
};
/**
 * check if 721 is approved by user
 */
const isApproved = async (creator) => {
  const isApproved = await erc721instance.isApprovedForAll(
    creator.address,
    erc721Delegate.address
  );
  console.log("isApproved: ", isApproved);
};
/**
 * get marketplace address
 */
const getMarketplaceAddress = async () => {
  const response = await erc721instance.getMarketplaceAddress();
  console.log("marketplace: ", response);
};

/**
 * get marketplace address
 */
const getTokenCreator = async (tokenId) => {
  const response = await erc721instance.tokenCreator(tokenId);
  console.log(`tokenId ${tokenId} creator addr: `, response);
};

const getTokenRoyalty = async (tokenId) => {
  const response = await erc721instance.tokenRoyalty(tokenId);
  console.log("token creator addr: ", Number(response) / 10000);
};

const tranferToken = async (from, buyer, tokenId) => {
  // const response = await erc721instance
  //   .connect(from)
  //   .transferFrom(from.address, buyer, tokenId, "TRANSFER");
  // await response.wait();
  console.log("transfer confirmed");
  const owner = await erc721instance.ownerOf(tokenId);
  console.log("new owner: ", owner);
};

const getTokenURI = async (tokenId) => {
  const a = await erc721instance.tokenURI(tokenId);
  console.log("tokenURI", a);
};
const main = async () => {
  // await create721(seller);
  // await approve721DelegateContract(seller);
  // await isApproved(seller);

  await getMarketplaceAddress();
  await getTokenCreator(1);
  await getTokenRoyalty(1);
  await tranferToken(seller, buyer.address, 1);
  await getTokenURI(2);
};
main()
  .then((_) => {})
  .catch((err) => console.log(err));

//tokenIds minted 1,2
