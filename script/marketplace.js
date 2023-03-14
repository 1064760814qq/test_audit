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
const { generateOrder, getInputHash, getOrderHash } = require("./utils");

let fee = [
  { percentage: 1000, to: "0x098F9C5E939be25D2699ECa7dfd1d057C6764c42" },
];
let bid = {
  highestBidder: ethers.constants.AddressZero,
  highestBid: 0,
};
let newOrder = null;

const grantRoleMarketAddr721 = async () => {
  const DELEGATION_CALLER = await erc721Delegate.DELEGATION_CALLER();
  const DELEGATION_CALLER1155 = await erc1155Delegate.DELEGATION_CALLER();

  const markTx = await erc721Delegate
    .connect(admin)
    .grantRole(DELEGATION_CALLER, marketplaceinstance.address);
  await markTx.wait();

  const response = await erc721Delegate
    .connect(admin)
    .hasRole(DELEGATION_CALLER, marketplaceinstance.address);
  console.log("hasrole", response);
};

const grantRoleMarketAddr1155 = async () => {
  const DELEGATION_CALLER = await erc1155Delegate.DELEGATION_CALLER();

  const markTx = await erc1155Delegate
    .connect(admin)
    .grantRole(DELEGATION_CALLER, marketplaceinstance.address);
  await markTx.wait();

  const response = await erc1155Delegate
    .connect(admin)
    .hasRole(DELEGATION_CALLER, marketplaceinstance.address);
  console.log("hasrole", response);
};

const updateDelegateAddress = async (toAdd = [], toremove = []) => {
  const markTx = await marketplaceinstance
    .connect(admin)
    .updateDelegates(toAdd, toremove);
  console.log("tx hash", markTx.hash);
  await markTx.wait();

  const response721 = await marketplaceinstance.delegates(
    erc721Delegate.address
  );
  const response1155 = await marketplaceinstance.delegates(
    erc1155Delegate.address
  );
  console.log("get delegate addr721", response721);
  console.log("get delegate addr1155", response1155);
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
  return isApproved;
};
const createAndSignOrder721 = async (seller, tokenId, side = 0) => {
  const price = String(ethers.utils.parseUnits("0.001", "ether"));
  const approved = await isApproved(seller);
  if (!approved) {
    console.log("CALLING APPROVED");
    await approve721DelegateContract(seller);
  }
  let order = generateOrder(
    erc721instance.address,
    seller.address,
    0, //BUY
    1, //ERC721
    tokenId,
    1,
    erc721Delegate.address,
    ethers.constants.AddressZero,
    price,
    0, //STATUS:NEW
    false, //Offer tokens
    [], //offerTokenAddress[]
    [], //offerTokenIds[]
    bid,
    fee
  );
  order.orderParams.salt = 1;
  const orderHash = getOrderHash(order.orderParams);
  const signature = await seller.signMessage(ethers.utils.arrayify(orderHash));
  const orderSigSplit = ethers.utils.splitSignature(signature);
  order.orderParams.r = orderSigSplit.r;
  order.orderParams.s = orderSigSplit.s;
  order.orderParams.v = orderSigSplit.v;

  return order.orderParams;
};

const buy = async (order, buyer, tokenId) => {
  const endTime = Math.round(Date.now() / 1000 + 1 * 60 * 1000);
  let settleUser = {
    salt: 1, //could be random number
    tokenAddress: erc721instance.address,
    tokenId: order.tokenId,
    amount: 1,
    deadline: order.endTime,
    delegateType: 1, //delegate type
    user: buyer.address, //who wants to settle the order: buyer
    price: order.price,
    acceptTokens: false,
    completed: false,
  };
  let input = {
    orders: Array(order),
    settle: settleUser,
  };
  const inputHash = getInputHash(input);
  const inputSignature = await buyer.signMessage(
    ethers.utils.arrayify(inputHash)
  );
  const inputSigSplit = ethers.utils.splitSignature(inputSignature);
  input.r = inputSigSplit.r;
  input.s = inputSigSplit.s;
  input.v = inputSigSplit.v;

  const response = await marketplaceinstance
    .connect(buyer)
    .execute(input, { value: order.price });
  console.log("buyreceipt", response.hash);
  await response.wait();
  console.log("CONFIRMED");
};

/**
 * cancel a order
 */
const cancelOrder = async (order, seller) => {
  const response = await marketplaceinstance
    .connect(seller)
    .cancel(order, order.endTime, order.v, order.r, order.s);
  console.log("receipt", response.hash);
  const tx = await response.wait();
  const cancelledHash = tx.logs[1];
  console.log("CONFIRMED", cancelledHash);
};

const main = async () => {
  /**
   * FIRST
   * need to grant DELEGATION Role to marketplace contract address
   * SECOND
   * need to update the Delegate address to marketplace contract
   */
  //   await grantRoleMarketAddr721();
  //   await grantRoleMarketAddr1155();
  /*******/
  //   await updateDelegateAddress(
  //     [erc721Delegate.address, erc1155Delegate.address],
  //     []
  //   );
  /**
   * rest of marketplace functions
   */
  newOrder = await createAndSignOrder721(seller, 2);
  //   await buy(newOrder, buyer);

  /**
   * CANCEL
   */
  await cancelOrder(newOrder, seller);
};

main()
  .then((_) => {})
  .catch((err) => console.log(err));
