const erc721 = artifacts.require("EchoooERC721");
const delegate721 = artifacts.require("ERC721Delegate");
const marketplace = artifacts.require("EchoooMarketplace");
const ethers = require("ethers");
const { adminPK, sellerPK, buyerPK } = require("./utils");

const url = "http://127.0.0.1:7545";
const provider = new ethers.providers.JsonRpcProvider(url);
const admin = new ethers.Wallet(adminPK, provider);
const seller = new ethers.Wallet(sellerPK, provider);
const buyer = new ethers.Wallet(buyerPK, provider);

contract("AlvinERC721 contract", (accounts) => {
  let erc721instance, del721Inst, marketplaceInst;
  let _721tokenId;
  beforeEach(async () => {
    erc721instance = new ethers.Contract(
      erc721.networks["5777"].address,
      erc721.abi,
      provider
    );
    del721Inst = new ethers.Contract(
      delegate721.networks["5777"].address,
      delegate721.abi,
      provider
    );
    marketplaceInst = new ethers.Contract(
      marketplace.networks["5777"].address,
      marketplace.abi,
      provider
    );
  });

  it("create a token", async () => {
    const tx = await erc721instance
      .connect(seller)
      .create(seller.address, 1000, "abc.com");
    const receipt = await tx.wait();
    _721tokenId = parseInt(receipt.logs[0].topics[3]);

    assert.equal(_721tokenId, 1);
  });
  it("set approve for all for ERC721Delegate Contract", async () => {
    const approvaltx = await erc721instance
      .connect(seller)
      .setApprovalForAll(delegate721.networks["5777"].address, true);
    await approvaltx.wait();
    const isApproved = await erc721instance.isApprovedForAll(
      seller.address,
      delegate721.networks["5777"].address
    );
    assert.equal(isApproved, true);
  });
  it("get marketplace address", async () => {
    const response = await erc721instance.getMarketplaceAddress();
    assert(response, marketplaceInst.address);
  });
  it("get token creator by tokenId", async () => {
    const response = await erc721instance.tokenCreator(_721tokenId);
    assert.equal(response, seller.address);
  });
  it("get token royalty by tokenId", async () => {
    const response = await erc721instance.tokenRoyalty(_721tokenId);
    assert.equal(Number(response), 1000);
  });
  it("transfer token to Buyer: tokenId-1", async () => {
    const response = await erc721instance
      .connect(seller)
      .transferFrom(seller.address, buyer.address, _721tokenId, "TRANSFER");
    await response.wait();
    const owner = await erc721instance.ownerOf(_721tokenId);

    assert.equal(owner, buyer.address);
  });
  it("seller is not an owner anymore of tokenId-1", async () => {
    const owner = await erc721instance.ownerOf(_721tokenId);
    assert.notEqual(owner, seller.address);
  });
  it("Buyer is current owner of tokenId-1", async () => {
    const owner = await erc721instance.ownerOf(_721tokenId);
    assert.equal(owner, buyer.address);
  });
  it("tokenURI", async () => {
    const a = await erc721instance.tokenURI(1);
    console.log("tokenURI", a);
  });
});
