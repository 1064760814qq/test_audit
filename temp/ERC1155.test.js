const erc1155 = artifacts.require("EchoooERC1155");
const delegate1155 = artifacts.require("ERC1155Delegate");
const marketplace = artifacts.require("EchoooMarketplace");
const ethers = require("ethers");
const { adminPK, sellerPK, buyerPK } = require("./utils");

const url = "http://127.0.0.1:7545";
const provider = new ethers.providers.JsonRpcProvider(url);
const admin = new ethers.Wallet(adminPK, provider);
const seller = new ethers.Wallet(sellerPK, provider);
const buyer = new ethers.Wallet(buyerPK, provider);

contract("AlvinERC1155 contract", (accounts) => {
  let erc1155instance, del1155Inst, marketplaceInst;
  let _1155tokenId;
  beforeEach(async () => {
    erc1155instance = new ethers.Contract(
      erc1155.networks["5777"].address,
      erc1155.abi,
      provider
    );
    del1155Inst = new ethers.Contract(
      delegate1155.networks["5777"].address,
      delegate1155.abi,
      provider
    );
    marketplaceInst = new ethers.Contract(
      marketplace.networks["5777"].address,
      marketplace.abi,
      provider
    );
  });

  it("create a token", async () => {
    const tx = await erc1155instance
      .connect(seller)
      .create(seller.address, 1000, 1);
    const receipt = await tx.wait();
    _1155tokenId = parseInt(receipt.logs[0].data.slice(0, 66));

    assert.equal(_1155tokenId, 1);
  });
  it("set approve for all for ERC721Delegate Contract", async () => {
    const approvaltx = await erc1155instance
      .connect(seller)
      .setApprovalForAll(delegate1155.networks["5777"].address, true);
    await approvaltx.wait();
    const isApproved = await erc1155instance.isApprovedForAll(
      seller.address,
      delegate1155.networks["5777"].address
    );
    assert.equal(isApproved, true);
  });
  it("get marketplace address", async () => {
    const response = await erc1155instance.getMarketplaceAddress();
    assert.equal(response, marketplaceInst.address);
  });
  it("get token creator by tokenId", async () => {
    const response = await erc1155instance.tokenCreator(_1155tokenId);
    assert.equal(response, seller.address);
  });
  it("get token royalty by tokenId", async () => {
    const response = await erc1155instance.tokenRoyalty(_1155tokenId);
    assert.equal(Number(response), 1000);
  });
  it("transfer token to Buyer: tokenId-1", async () => {
    const response = await erc1155instance
      .connect(seller)
      .safeTransferFrom(
        seller.address,
        buyer.address,
        _1155tokenId,
        1,
        [],
        "TRANSFER"
      );
    await response.wait();
    const owner = await erc1155instance.balanceOf(seller.address, _1155tokenId);
    assert.equal(owner, 0);
  });
  it("seller is not an owner anymore of tokenId-1", async () => {
    const owner = await erc1155instance.balanceOf(seller.address, _1155tokenId);
    assert.notEqual(Number(owner), 1);
  });
  it("Buyer is current owner of tokenId-1", async () => {
    const owner = await erc1155instance.balanceOf(buyer.address, _1155tokenId);
    assert.equal(Number(owner), 1);
  });
  it("tokenURI", async () => {
    const a = await erc1155instance.uri(1);
    console.log("tokenURI", a);
  });
});
