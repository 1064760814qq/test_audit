const erc721 = artifacts.require("EchoooERC721");
const marketplace = artifacts.require("EchoooMarketplace");
const delegate721 = artifacts.require("ERC721Delegate");
const mockWeth = artifacts.require("MockWETH");
const EchoooMulticall = artifacts.require("EchoooMulticall");
const ethers = require("ethers");
const {
  getInputHash,
  getOrderHash,
  generateOrder,
  adminPK,
  sellerPK,
  buyerPK,
} = require("./utils");

const url = "http://127.0.0.1:7545";
const provider = new ethers.providers.JsonRpcProvider(url);
const admin = new ethers.Wallet(adminPK, provider);
const seller = new ethers.Wallet(sellerPK, provider);
const buyer = new ethers.Wallet(buyerPK, provider);

contract("Marketplace contracts", (accounts) => {
  let erc721instance, marketplaceInst, del721Inst, mockWethInst, multicall;
  let _721tokenId, tokenId2;
  const ERC721_TYPE = 1;
  const ERC1155_TYPE = 2;
  //   const [admin, trader1, trader2] = [accounts[0], accounts[1], accounts[2]];
  beforeEach(async () => {
    erc721instance = new ethers.Contract(
      erc721.networks["5777"].address,
      erc721.abi,
      provider
    );
    marketplaceInst = new ethers.Contract(
      marketplace.networks["5777"].address,
      marketplace.abi,
      provider
    );
    del721Inst = new ethers.Contract(
      delegate721.networks["5777"].address,
      delegate721.abi,
      provider
    );
    mockWethInst = new ethers.Contract(
      mockWeth.networks["5777"].address,
      mockWeth.abi,
      provider
    );
    multicall = new ethers.Contract(
      EchoooMulticall.networks["5777"].address,
      EchoooMulticall.abi,
      provider
    );

    // console.log("erc721instance", erc721instance.address);
    // console.log("marketplaceInst", marketplaceInst.address);
    // console.log("del721Inst", del721Inst.address);
    // console.log("mockWethInst", mockWethInst.address);
  });
  it("check WETH balance", async () => {
    const sellerBal = await mockWethInst.balanceOf(seller.address);
    console.log("Seller:", ethers.utils.formatEther(sellerBal, "ether"));
    const buyerBal = await mockWethInst.balanceOf(buyer.address);
    console.log("Buyer:", ethers.utils.formatEther(buyerBal, "ether"));
  });
  it("create 721s", async () => {
    const tx = await erc721instance
      .connect(seller)
      .create(seller.address, 1000, "abc.com");
    const receipt = await tx.wait();
    _721tokenId = parseInt(receipt.logs[0].topics[3]);
    const tx1 = await erc721instance
      .connect(seller)
      .create(seller.address, 1000, "abc.com");
    const receipt1 = await tx1.wait();
    tokenId2 = parseInt(receipt1.logs[0].topics[3]);
    console.log("tokenId1", _721tokenId, tokenId2);
    const approvaltx = await erc721instance
      .connect(seller)
      .setApprovalForAll(delegate721.networks["5777"].address, true);
    await approvaltx.wait();
    const isApproved = await erc721instance.isApprovedForAll(
      seller.address,
      delegate721.networks["5777"].address
    );
    assert.equal(_721tokenId, 1);
    assert.equal(isApproved, true);
  });
  it("allow admin to setApproveForAll contract addr", async () => {
    const approvaltx = await erc721instance
      .connect(admin)
      .setApprovalForAll(delegate721.networks["5777"].address, true);
    await approvaltx.wait();
    const isApproved = await erc721instance.isApprovedForAll(
      admin.address,
      delegate721.networks["5777"].address
    );

    assert.equal(isApproved, true);
  });
  // it("use multicall to call setApprovalForAll", async () => {
  //   const iface = new ethers.utils.Interface(erc721.abi);
  //   const data = iface.encodeFunctionData("setApprovalForAll", [
  //     delegate721.networks["5777"].address,
  //     true,
  //   ]);
  //   // const data1 = iface.encodeFunctionData("setApprovalForAll", [
  //   //   delegate721.networks["5777"].address,
  //   //   true,
  //   // ]);
  //   const r = await multicall.connect(seller).multicallExecute(Array(String(data)));
  //   const a = await r.wait();
  //   console.log(a);

  //});
  it("grant DELEGATION_CALLER role to marketplace address", async () => {
    const DELEGATION_CALLER = await del721Inst.DELEGATION_CALLER();
    //0x7630198b183b603be5df16e380207195f2a065102b113930ccb600feaf615331

    const markTx = await del721Inst
      .connect(admin)
      .grantRole(DELEGATION_CALLER, marketplaceInst.address);
    await markTx.wait();

    const response = await del721Inst
      .connect(admin)
      .hasRole(DELEGATION_CALLER, marketplaceInst.address);
    assert.equal(response, true);
  });
  it("update delegate address marketplace", async () => {
    const toAdd = [del721Inst.address];
    const toremove = [];
    const markTx = await marketplaceInst
      .connect(admin)
      .updateDelegates(toAdd, toremove);
    await markTx.wait();

    const response = await marketplaceInst.delegates(toAdd[0]);
    assert.equal(response, true);
  });

  it("bulk purchase create a listing to sell and making a purchase", async () => {
    const salt = Math.floor(Math.random() * 10000000000000 + 1);
    const startTime = Math.round(Date.now() / 1000);
    const endTime = Math.round(startTime + 1 * 60 * 1000);
    const price = String(ethers.utils.parseUnits("1", "ether"));
    const fee = [{ percentage: 1000, to: admin.address }];
    //
    let bid = {
      highestBidder: ethers.constants.AddressZero,
      highestBid: 0,
    };
    let order = {
      salt: salt,
      tokenAddress: erc721instance.address,
      user: seller.address,
      side: 0, //order type : BUY(when seller is lisitng a token)
      delegateType: ERC721_TYPE, //delegate type (1: ERC721)
      tokenId: _721tokenId,
      amount: 1, //number of copies (1 for ERC721 type)
      executionDelegate: del721Inst.address, //(721 delegate address)
      currencyAddress: ethers.constants.AddressZero,
      price: price,
      startTime: startTime,
      endTime: endTime,
      status: 0,
      offerTokens: false,
      offerTokenAddress: [],
      offerTokenIds: [],
      fee: fee,
      bid: bid,
    };
    let order2 = {
      salt: 1,
      tokenAddress: erc721instance.address,
      user: seller.address,
      side: 0, //order type : BUY(when seller is lisitng a token)
      delegateType: ERC721_TYPE, //delegate type (1: ERC721)
      tokenId: tokenId2,
      amount: 1, //number of copies (1 for ERC721 type)
      executionDelegate: del721Inst.address, //(721 delegate address)
      currencyAddress: ethers.constants.AddressZero,
      price: price,
      startTime: startTime,
      endTime: endTime,
      status: 0,
      offerTokens: false,
      offerTokenAddress: [],
      offerTokenIds: [],
      fee: fee,
      bid: bid,
    };
    let settleUser = {
      salt: 2,
      tokenAddress: erc721instance.address,
      tokenId: _721tokenId,
      amount: 1,
      deadline: endTime,
      delegateType: ERC721_TYPE, //delegate type
      user: buyer.address, //who wants to settle the order: buyer
      price: String(ethers.utils.parseUnits("1", "ether")),
      acceptTokens: false,
      completed: false,
    };

    const orderHash = getOrderHash(order);
    const orderHash2 = getOrderHash(order2);
    const signature = await seller.signMessage(
      ethers.utils.arrayify(orderHash)
    );
    const orderSigSplit = ethers.utils.splitSignature(signature);
    order.r = orderSigSplit.r;
    order.s = orderSigSplit.s;
    order.v = orderSigSplit.v;
    const signature2 = await seller.signMessage(
      ethers.utils.arrayify(orderHash2)
    );
    const orderSigSplit2 = ethers.utils.splitSignature(signature2);
    order2.r = orderSigSplit2.r;
    order2.s = orderSigSplit2.s;
    order2.v = orderSigSplit2.v;

    let input = {
      orders: Array(order, order2),
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

    console.log(input);
    //check balances
    const sellerBalanceBefore = await seller.getBalance();
    console.log(
      "Before: seller balance",
      ethers.utils.formatEther(sellerBalanceBefore, "ether")
    );
    const buyerBalanceBefore = await buyer.getBalance();
    console.log(
      "Before: buyer balance",
      ethers.utils.formatEther(buyerBalanceBefore, "ether")
    );
    //buyer will call the execute function
    await marketplaceInst.connect(buyer).callStatic.executeBuy(input, {
      value: String(ethers.utils.parseUnits("2", "ether")),
    });
    // console.log("staticCall", staticCall);
    const buyreceipt = await marketplaceInst.connect(buyer).executeBuy(input, {
      value: String(ethers.utils.parseUnits("2", "ether")),
    });
    await buyreceipt.wait();

    //after check balances
    const sellerBalanceAfter = await seller.getBalance();
    console.log(
      "After: seller balance",
      ethers.utils.formatEther(sellerBalanceAfter, "ether")
    );
    const buyerBalanceAfter = await buyer.getBalance();
    console.log(
      "After: buyer balance",
      ethers.utils.formatEther(buyerBalanceAfter, "ether")
    );
  });

  it("check token owner", async () => {
    const approvaltx = await erc721instance.ownerOf(_721tokenId);
    const approvaltx1 = await erc721instance.ownerOf(tokenId2);
    console.log("current owner1", approvaltx);
    console.log("current owner2", approvaltx1);
  });
  // it("Approve marketplace instance to spend WETH on behalf of user", async () => {
  //   const amount =
  //     "115792089237316195423570985008687907853269984665640564039457584007913129639935";
  //   const checkAmoutn = 115792089237316195423570985008687907853269984665640564039457.584007913129639935;
  //   const appTx = await mockWethInst
  //     .connect(buyer)
  //     .approve(marketplaceInst.address, amount);
  //   const appTx1 = await mockWethInst
  //     .connect(seller)
  //     .approve(marketplaceInst.address, amount);
  //   await appTx.wait();
  //   await appTx1.wait();

  //   const allowance = await mockWethInst.allowance(
  //     buyer.address,
  //     marketplaceInst.address
  //   );
  //   const allowance2 = await mockWethInst.allowance(
  //     seller.address,
  //     marketplaceInst.address
  //   );
  //   assert.equal(checkAmoutn, ethers.utils.formatEther(allowance, "ether"));
  //   assert.equal(checkAmoutn, ethers.utils.formatEther(allowance2, "ether"));
  // });
  // it("creating an offer and accepting it", async () => {
  //   const salt = Math.floor(Math.random() * 10000000000000 + 1);
  //   const startTime = Math.round(Date.now() / 1000);
  //   const endTime = Math.round(startTime + 1 * 60 * 1000);
  //   const price = String(ethers.utils.parseUnits("0.5", "ether"));
  //   const fee = [{ percentage: 1000, to: admin.address }];
  //   let bid = {
  //     highestBidder: ethers.constants.AddressZero,
  //     highestBid: 0,
  //   };
  //   let order = {
  //     salt: salt,
  //     tokenAddress: erc721instance.address,
  //     user: seller.address,
  //     side: 1, //order type : OFFER(when buyer is making an offer)
  //     delegateType: ERC721_TYPE, //delegate type (1: ERC721)
  //     tokenId: _721tokenId,
  //     amount: 1, //number of copies (1 for ERC721 type)
  //     executionDelegate: del721Inst.address, //(721 delegate address)
  //     currencyAddress: mockWethInst.address, //(ERC20:WETH address)
  //     price: price,
  //     startTime: startTime,
  //     endTime: endTime,
  //     status: 0,
  //     offerTokens: false,
  //     offerTokenAddress: [],
  //     offerTokenIds: [],
  //     fee: fee,
  //     bid: bid,
  //   };
  //   let settleUser = {
  //     salt: salt,
  //     tokenAddress: erc721instance.address,
  //     tokenId: _721tokenId,
  //     amount: 1,
  //     deadline: endTime,
  //     delegateType: ERC721_TYPE, //delegate type
  //     user: buyer.address, //who wants to settle the order: buyer
  //     price: price,
  //     acceptTokens: false,
  //     completed: false,
  //   };
  //   let input = {
  //     orders: Array(order),
  //     settle: settleUser,
  //   };
  //   const orderHash = getOrderHash(order);
  //   const inputHash = getInputHash(input);
  //   const signature = await seller.signMessage(
  //     ethers.utils.arrayify(orderHash)
  //   );
  //   const iSignature = await buyer.signMessage(
  //     ethers.utils.arrayify(inputHash)
  //   );

  //   const orderSigSplit = ethers.utils.splitSignature(signature);
  //   order.r = orderSigSplit.r;
  //   order.s = orderSigSplit.s;
  //   order.v = orderSigSplit.v;

  //   const inputSigSplit = ethers.utils.splitSignature(iSignature);
  //   input.r = inputSigSplit.r;
  //   input.s = inputSigSplit.s;
  //   input.v = inputSigSplit.v;

  //   //   // calling setApprovalForAll
  //   const approvaltx = await erc721instance
  //     .connect(buyer)
  //     .setApprovalForAll(delegate721.networks["5777"].address, true);
  //   await approvaltx.wait();
  //   //buyer will call the execute function
  //   await marketplaceInst.connect(buyer).callStatic.executeOffer(input, {
  //     value: 0,
  //   });
  //   const eg = await marketplaceInst
  //     .connect(buyer)
  //     .estimateGas.executeOffer(input, { value: 0 });

  //   const offerTx = await marketplaceInst
  //     .connect(buyer)
  //     .executeOffer(input, { value: 0, gasLimit: Number(eg) });
  //   await offerTx.wait();
  //   const owner = await erc721instance.ownerOf(_721tokenId);
  //   assert.equal(owner, seller.address); //offer of 0.5WETH was made by seller and accepted by buyer
  // });

  // it("offer token for a token", async () => {
  //   for (let i = 0; i < 2; i++) {
  //     const t = await erc721instance
  //       .connect(seller)
  //       .create(buyer.address, 1000, "abc.com");
  //     await t.wait();
  //   }

  //   const salt = Math.floor(Math.random() * 10000000000000 + 1);
  //   const startTime = Math.round(Date.now() / 1000);
  //   const endTime = Math.round(startTime + 1 * 60 * 1000);
  //   const price = String(ethers.utils.parseUnits("0", "ether"));
  //   const fee = [{ percentage: 1000, to: admin.address }];
  //   let bid = {
  //     highestBidder: ethers.constants.AddressZero,
  //     highestBid: 0,
  //   };
  //   let order = {
  //     salt: salt,
  //     tokenAddress: erc721instance.address,
  //     user: buyer.address,
  //     side: 1, //order type : OFFER(when buyer is making an offer)
  //     delegateType: ERC721_TYPE, //delegate type (1: ERC721)
  //     tokenId: _721tokenId,
  //     amount: 1, //number of copies (1 for ERC721 type)
  //     executionDelegate: del721Inst.address, //(721 delegate address)
  //     currencyAddress: mockWethInst.address, //(ERC20:WETH address)
  //     price: price, // price would be 0 if only offering token
  //     startTime: startTime,
  //     endTime: endTime,
  //     status: 0,
  //     offerTokens: true,
  //     offerTokenAddress: [erc721instance.address, erc721instance.address],
  //     offerTokenIds: [2, 3],
  //     fee: fee,
  //     bid: bid,
  //   };
  //   let settleUser = {
  //     salt: salt,
  //     tokenAddress: erc721instance.address,
  //     tokenId: _721tokenId,
  //     amount: 1,
  //     deadline: endTime,
  //     delegateType: ERC721_TYPE, //delegate type
  //     user: seller.address, //who wants to settle the order: buyer
  //     price: price,
  //     acceptTokens: true,
  //     completed: false,
  //   };
  //   let input = {
  //     orders: Array(order),
  //     settle: settleUser,
  //   };
  //   const orderHash = getOrderHash(order);
  //   const inputHash = getInputHash(input);
  //   const osignature = await buyer.signMessage(
  //     ethers.utils.arrayify(orderHash)
  //   );
  //   const iSignature = await seller.signMessage(
  //     ethers.utils.arrayify(inputHash)
  //   );

  //   const orderSigSplit = ethers.utils.splitSignature(osignature);
  //   order.r = orderSigSplit.r;
  //   order.s = orderSigSplit.s;
  //   order.v = orderSigSplit.v;

  //   const inputSigSplit = ethers.utils.splitSignature(iSignature);
  //   input.r = inputSigSplit.r;
  //   input.s = inputSigSplit.s;
  //   input.v = inputSigSplit.v;
  //   await marketplaceInst.connect(seller).callStatic.executeOffer(input, {
  //     value: 0,
  //   });
  //   const r = await marketplaceInst.connect(seller).executeOffer(input, {
  //     value: 0,
  //   });
  //   await r.wait();
  //   const owner1 = await erc721instance.ownerOf(_721tokenId);
  //   const owner2 = await erc721instance.ownerOf(2);
  //   const owner3 = await erc721instance.ownerOf(3);
  //   assert.equal(owner1, buyer.address);
  //   assert.equal(owner2, seller.address);
  //   assert.equal(owner3, seller.address); //offer made by buyer in exchnage of token2&3 for token1
  // });

  // it("auction", async () => {
  //   const price = String(ethers.utils.parseUnits("0.5", "ether"));
  //   const fee = [{ percentage: 2000, to: admin.address }];
  //   let bid = {
  //     highestBidder: ethers.constants.AddressZero,
  //     highestBid: 0,
  //   };
  //   const tx = await erc721instance
  //     .connect(seller)
  //     .create(seller.address, 1000, "abc.com");
  //   const receipt = await tx.wait();
  //   const _tokenId = parseInt(receipt.logs[0].topics[3]);
  //   const order = generateOrder(
  //     erc721instance.address,
  //     seller.address,
  //     2, // side
  //     ERC721_TYPE,
  //     _tokenId, //tokenId
  //     1, //amount
  //     del721Inst.address, //delegation addres
  //     mockWethInst.address, //currency address
  //     price,
  //     3, //AUCTION
  //     false,
  //     [],
  //     [],
  //     bid,
  //     fee
  //   );
  //   const orderHash = getOrderHash(order.orderParams);
  //   const osignature = await seller.signMessage(
  //     ethers.utils.arrayify(orderHash)
  //   );

  //   const orderSigSplit = ethers.utils.splitSignature(osignature);
  //   order.orderParams.r = orderSigSplit.r;
  //   order.orderParams.s = orderSigSplit.s;
  //   order.orderParams.v = orderSigSplit.v;

  //   //place bid/offer
  //   const price1 = String(ethers.utils.parseUnits("0.6", "ether"));
  //   bid = {
  //     highestBidder: buyer.address,
  //     highestBid: price1,
  //   };
  //   const bid1 = generateOrder(
  //     erc721instance.address,
  //     buyer.address,
  //     2, // side
  //     ERC721_TYPE,
  //     _tokenId, //tokenId
  //     1, //amount
  //     del721Inst.address, //delegation addres
  //     mockWethInst.address, //currency address
  //     price,
  //     3, //AUCTION
  //     false,
  //     [],
  //     [],
  //     bid,
  //     fee
  //   );
  //   const bidHash1 = getOrderHash(bid1.orderParams);
  //   const bsignature1 = await buyer.signMessage(
  //     ethers.utils.arrayify(bidHash1)
  //   );
  //   const brderSigSplit1 = ethers.utils.splitSignature(bsignature1);
  //   bid1.orderParams.r = brderSigSplit1.r;
  //   bid1.orderParams.s = brderSigSplit1.s;
  //   bid1.orderParams.v = brderSigSplit1.v;

  //   //execute the bid -> offer of 0.6

  //   let settleUser = {
  //     salt: Math.floor(Math.random() * 10000000000000 + 1),
  //     tokenAddress: erc721instance.address,
  //     tokenId: _tokenId,
  //     amount: 1,
  //     deadline: bid1.orderParams.endTime,
  //     delegateType: ERC721_TYPE, //delegate type
  //     user: seller.address, //who wants to settle the order: buyer
  //     price: price1,
  //     acceptTokens: false,
  //     completed: false,
  //   };
  //   let input = {
  //     orders: Array(bid1.orderParams),
  //     settle: settleUser,
  //   };
  //   const inputHash = getInputHash(input);
  //   const isignature1 = await seller.signMessage(
  //     ethers.utils.arrayify(inputHash)
  //   );

  //   const inputSigSplit1 = ethers.utils.splitSignature(isignature1);
  //   input.r = inputSigSplit1.r;
  //   input.s = inputSigSplit1.s;
  //   input.v = inputSigSplit1.v;
  //   // console.log(input);

  //   await marketplaceInst.connect(seller).callStatic.executeAuction(input, {
  //     value: 0,
  //   });
  // });
});
