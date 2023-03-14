const ethers = require("ethers");
class Order {
  orderParams;

  constructor(orderParams) {
    this.orderParams = orderParams;
  }

  getOrder() {
    return this.orderParams;
  }
}

const generateOrder = (
  tokenAddress,
  userAddress,
  side,
  delegateType,
  tokenId,
  amount,
  executionDelegate,
  currencyAddress,
  price,
  status = 0,
  offerTokens = false,
  offerTokenAddress = [],
  offerTokenIds = [],
  bid,
  fee = []
) => {
  const salt = Math.floor(Math.random() * 10000000000000 + 1);
  const startTime = Math.round(Date.now() / 1000);
  const endTime = Math.round(startTime + 1 * 60 * 1000);
  return new Order({
    salt: salt,
    tokenAddress: tokenAddress,
    user: userAddress,
    side: side, //order type : OFFER(when buyer is making an offer)
    delegateType: delegateType, //delegate type (1: ERC721)
    tokenId: tokenId,
    amount: amount, //number of copies (1 for ERC721 type)
    executionDelegate: executionDelegate, //(721 delegate address)
    currencyAddress: currencyAddress, //(ERC20:WETH address)
    price: price, // price would be 0 if only offering token
    startTime: startTime,
    endTime: endTime,
    status: status,
    offerTokens: offerTokens,
    offerTokenAddress: offerTokenAddress,
    offerTokenIds: offerTokenIds,
    bid: bid,
    fee: fee,
  });
};
const getOrderHash = (order) => {
  return ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      ["uint256", "address", "uint256", "uint256", "uint256", "uint256"],
      [
        order.salt,
        order.user,
        order.side,
        order.delegateType,
        order.amount,
        order.tokenId,
      ]
    )
  );
};
const getInputHash = (input) => {
  return ethers.utils.keccak256(
    ethers.utils.defaultAbiCoder.encode(
      [
        "uint256",
        "address",
        "uint256",
        "uint256",
        "uint256",
        "uint256",
        "address",
        "uint256",
        "bool",
        "bool",
        "uint256",
      ],
      [
        input.settle.salt,
        input.settle.tokenAddress,
        input.settle.tokenId,
        input.settle.amount,
        input.settle.deadline,
        input.settle.delegateType,
        input.settle.user,
        input.settle.price,
        input.settle.acceptTokens,
        input.settle.completed,
        input.orders.length,
      ]
    )
  );
};

const adminPK =
  "89a3ded1794385039171084269d167e2c03e27f92b2097d951f6c31356f21df1";
const sellerPK =
  "9b74f0d2b39f15b418ae219e0d70ad893fac9422aff1ce3fa93553ea3831d2b1";
const buyerPK =
  "4d91220152d127d89cfb9e456b161ef58d55e1ce3f9f3b8efa3904de7f926b7a";
module.exports = {
  getInputHash,
  getOrderHash,
  Order,
  generateOrder,
  adminPK,
  sellerPK,
  buyerPK,
};
