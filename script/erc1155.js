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
const create1155 = async (creator) => {
  const response = await erc1155instance
    .connect(creator)
    .create(seller.address, 1000, 1);
  console.log("tx hash: ", response.hash);
  const receipt = await response.wait();
  const _1155tokenId = parseInt(receipt.logs[0].data.slice(0, 66));

  console.log("tokenId-", _1155tokenId);
};

/**
 * approve 721Delegate address to allow transfers on basis of user
 */
const approve1155DelegateContract = async (creator) => {
  const response = await erc1155instance
    .connect(creator)
    .setApprovalForAll(erc1155Delegate.address, true);
  console.log("tx hash: ", response.hash);
  await response.wait();
  console.log("confirmed");
};
/**
 * check if 721 is approved by user
 */
const isApproved = async (creator) => {
  const isApproved = await erc1155instance.isApprovedForAll(
    creator.address,
    erc1155Delegate.address
  );
  console.log("isApproved: ", isApproved);
};
/**
 * get marketplace address
 */
const getMarketplaceAddress = async () => {
  const response = await erc1155instance.getMarketplaceAddress();
  console.log("marketplace: ", response);
};

/**
 * get marketplace address
 */
const getTokenCreator = async (tokenId) => {
  const response = await erc1155instance.tokenCreator(tokenId);
  console.log(`tokenId ${tokenId} creator addr: `, response);
};

const getTokenRoyalty = async (tokenId) => {
  const response = await erc1155instance.tokenRoyalty(tokenId);
  console.log("token creator addr: ", Number(response) / 10000);
};

const tranferToken = async (from, buyer, tokenId, amount = 1) => {
  const response = await erc1155instance
    .connect(from)
    .safeTransferFrom(seller.address, buyer, tokenId, amount, [], "TRANSFER");
  await response.wait();
  console.log("transfer confirmed");
  const owner = await erc1155instance.balanceOf(buyer, tokenId);
  console.log("new owner balance: ", Number(owner));
};

const getTokenURI = async (tokenId) => {
  const a = await erc1155instance.uri(tokenId);
  console.log("tokenURI", a);
};
const main = async () => {
  await create1155(seller);
  await approve1155DelegateContract(seller);
  await isApproved(seller);

  await getMarketplaceAddress();
  await getTokenCreator(1);
  await getTokenRoyalty(1);
  await tranferToken(seller, buyer.address, 1, 1);
  await getTokenURI(1);
};
main()
  .then((_) => {})
  .catch((err) => console.log(err));

//tokenIds minted 1
