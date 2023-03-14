const Web3 = require("web3");
const ERC721 = require("./build/contracts/AlvinERC721.json");
const ERC1155 = require("./build/contracts/AlvinERC1155.json");
const Marketplace = require("./build/contracts/AlvinMarketplace.json");

const ERC721Addr = ERC721.networks["5777"].address;
const ERC1155Addr = ERC1155.networks["5777"].address;
// const ERC1155Addr = "0x6108eb577431DF3D6cC61333Bc4D75263bD42e08";
const MarketplaceAddr = Marketplace.networks["5777"].address;

const user1Addr = "0x02d88FA99F60214FD399ccD2CedD7b6727e5eB81";
const user1PK =
  "c1b2ac7c5bc50130665193725969cb67028992a74647b2e42601147584d5a765";

const buyerAddr = "0x2fFabA54AfF35C0C6037A370C45287B9b3ef8514";
const buyerPK =
  "d36e90664aa9eb9a02b078be31d1c78ea8c72e0394278558974e4390b9ef91e7";
const buyerAddr2 = "0xe47d48A6313D28c49aA424c318Aeb2c48e91B296";
const buyerPK2 =
  "643c6fffec1dc888983a6ac55c6fd5e6c57aed0b965744b8a99f07d6342ac42e";

const RAPID_API_KEY = "5a32206bdcmsh8aca2e4b16b5290p10ec05jsnc811c81d71d3";

const provider = new Web3.providers.HttpProvider(
  "https://blockchain-http-rpc1.p.rapidapi.com/api/ethereum/goerli",
  {
    headers: [
      {
        name: "X-RapidAPI-Key",
        value: RAPID_API_KEY,
      },
      {
        name: "X-RapidAPI-Host",
        value: "blockchain-http-rpc1.p.rapidapi.com",
      },
    ],
  }
);

const web3 = new Web3(
  // provider
  new Web3.providers.HttpProvider(
    "http://127.0.0.1:7545"
    // "https://goerli.infura.io/v3/511db41b27f84f4497676adb7905871f"
  )
);

const erc721Instance = new web3.eth.Contract(ERC721.abi, ERC721Addr);
const erc1155Instance = new web3.eth.Contract(ERC1155.abi, ERC1155Addr);
const marketplaceInstance = new web3.eth.Contract(
  Marketplace.abi,
  MarketplaceAddr
);

const signTransaction = async (data, from, to, value = 0, privateKey) => {
  const txParams = {
    to,
    value,
    data,
    from,
    gas: 5000000,
  };
  const tx = await web3.eth.accounts.signTransaction(txParams, privateKey);
  console.log("tx", tx.transactionHash);
  console.log("status", "PENDING....");
  const signedTxSend = web3.eth.sendSignedTransaction(tx?.rawTransaction);
  const res = await new Promise((resolve, reject) => {
    signedTxSend.once("error", (err) => {
      console.log("err data", err.data);
      reject(err);
    });

    signedTxSend.on("confirmation", (confirmationNumber, receipt) => {
      // For production environment, we should use a larger confirmation number
      if (confirmationNumber > 0) {
        resolve(receipt);
      } else {
        console.log(confirmationNumber);
      }
    });
  });
  return res;
};
/** get outstanding balance */
const getOutstandingBalance = async (address) => {
  const balance = await marketplaceInstance.methods
    .outstandingPayment(address)
    .call();
  console.log(web3.utils.fromWei(balance, "ether") + "ETH");
};

/*** withdraw outstanding balance */
const withdrawOutstandingPayment = async (userAddr, userpk) => {
  const data = await marketplaceInstance.methods.withdrawPayment().encodeABI();
  console.log("userAddr", userAddr);
  const receipt = await signTransaction(
    data,
    userAddr,
    MarketplaceAddr,
    0,
    userpk
  );
  console.log(receipt.logs);
};
/**
 *
 *royalty needs to be multiple of 10000, and can goes from 0 to 10%
 * if it is 10% -> 10 * 10000
 * if its 2000 -> its set to be 0.2%
 */
const create721Token = async (
  creatorAddr,
  creatorPK,
  royalty = 1000,
  tokenURI = "https://abc.com"
) => {
  const data = await erc721Instance.methods
    .create(creatorAddr, royalty, tokenURI)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    creatorAddr,
    ERC721Addr,
    0,
    creatorPK
  );

  const tokenId = parseInt(receipt.logs[0].topics[3]);
  console.log("tokeId--", tokenId);
  console.log(receipt.logs[0]);
  const tokenroyalty = await erc721Instance.methods
    .tokenRoyalty(tokenId)
    .call();
  console.log("Royalty of tokenId->", tokenroyalty);
  const royaltyInfo = await erc721Instance.methods
    .royaltyInfo(tokenId, web3.utils.toWei("1", "ether"))
    .call();
  console.log("royaltyInfo--", royaltyInfo);
  // erc721Instance.once("Transfer", (error, res) => {
  //   console.log("event", error);
  //   console.log("event", res);
  // });
  return true;
};
/**
 *
 * check if user is having royalty or not
 * need to change the instance accordingly
 */
const checkUserRoyalty = async (tokenId) => {
  const royalty = await erc1155Instance.methods.tokenRoyalty(tokenId).call();
  console.log("Royalty of tokenId->", royalty);
};
const create1155Token = async (
  creatorAddr,
  numberOfCopies,
  creatorPK,
  royalty = 1000
) => {
  const data = await erc1155Instance.methods
    .create(creatorAddr, royalty, numberOfCopies)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    creatorAddr,
    ERC1155Addr,
    0,
    creatorPK
  );

  const tokenId = parseInt(receipt.logs[0].data.slice(0, 66));

  console.log("tokeId--", tokenId);

  const tokenroyalty = await erc1155Instance.methods
    .tokenRoyalty(tokenId)
    .call();
  console.log("Royalty of tokenId->", tokenroyalty);
  const royaltyInfo = await erc1155Instance.methods
    .royaltyInfo(tokenId, web3.utils.toWei("1", "ether"))
    .call();
  console.log("royaltyInfo--", royaltyInfo);
};

const listToken = async (
  creatorAddr,
  creatorPK,
  contractAddr,
  assetType,
  tokenId,
  status,
  numOfCopies,
  price
) => {
  let startTime = 0,
    endTime = 0;
  if (status === 2) {
    startTime = Date.now() + 6000;
    endTime = startTime + 5 * 60 * 1000;
  }
  console.log("status", status);
  const data = await marketplaceInstance.methods
    .setListing(
      contractAddr,
      assetType,
      tokenId,
      status,
      numOfCopies,
      price,
      Math.round(startTime / 1000),
      Math.round(endTime / 1000)
    )
    .encodeABI();
  const receipt = await signTransaction(
    data,
    creatorAddr,
    MarketplaceAddr,
    0,
    creatorPK
  );
  console.log(receipt);
};
const getListing = async (contractAddr, userAddr, tokenId) => {
  const res = await marketplaceInstance.methods
    .listingOf(contractAddr, userAddr, tokenId)
    .call();
  console.log(res);
};

const buyListing = async (
  buyerAddr,
  buyerPK,
  tokenId,
  numOfCopies,
  itemOwner,
  contractAddr,
  price
) => {
  const instance =
    (contractAddr.toLowerCase() === ERC1155Addr.toLowerCase() &&
      erc1155Instance) ||
    (contractAddr.toLowerCase() === ERC721Addr.toLowerCase() && erc721Instance);
  const tokenroyalty = await instance.methods.tokenRoyalty(tokenId).call();
  console.log(tokenroyalty);
  // let isERC2981 = false;
  // if (tokenroyalty !== 0) isERC2981 = true;

  const data = await marketplaceInstance.methods
    .buy(tokenId, numOfCopies, itemOwner, contractAddr, false, 0)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    buyerAddr,
    MarketplaceAddr,
    price,
    buyerPK
  );
  console.log("logs", receipt.logs);
};

const batchBuy = async (
  buyerAddr,
  buyerPK,
  tokenId,
  numOfCopies,
  itemOwner,
  contractAddr,
  price
) => {
  const data = await marketplaceInstance.methods
    .batchBuy(tokenId, numOfCopies, itemOwner, contractAddr)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    buyerAddr,
    MarketplaceAddr,
    price,
    buyerPK
  );
  console.log(receipt);
  console.log(receipt.logs);
};

const makeOffer = async (
  buyerAddr,
  buyerPK,
  contractAddress,
  assetType,
  tokenId,
  numOfCopies,
  price,
  typeNFT,
  offeredTokenAddress = [], //array
  offeredTokenId = [], //array
  itemOwner
) => {
  const startTime = Date.now();
  const endTime = startTime + 7 * 24 * 60 * 60 * 1000;

  const data = await marketplaceInstance.methods
    .makeOffer(
      contractAddress,
      assetType,
      tokenId,
      numOfCopies,
      Math.round(startTime / 1000),
      Math.round(endTime / 1000),
      typeNFT,
      offeredTokenAddress,
      offeredTokenId,
      itemOwner
    )
    .encodeABI();
  const receipt = await signTransaction(
    data,
    buyerAddr,
    MarketplaceAddr,
    price,
    buyerPK
  );
  console.log(receipt.logs);
  await getOfferByTimestamp(
    contractAddress,
    tokenId,
    buyerAddr,
    Math.round(startTime / 1000)
  );
};
const getAllOffers = async () => {
  const res = await marketplaceInstance.methods
    .getAllOffers(ERC721Addr, 1)
    .call();
  console.log(res);
};
const getOfferByTimestamp = async (
  contractAddr,
  tokenId,
  createdBy,
  startTime
) => {
  const res = await marketplaceInstance.methods
    .getOfferByTimestamp(contractAddr, tokenId, createdBy, startTime)
    .call();
  console.log(res);
};
const acceptOffer = async (
  userAddr,
  userPK,
  contractAddress,
  createdBy,
  tokenId,
  startTime
) => {
  console.log(contractAddress);
  const instance =
    (contractAddress.toLowerCase() === ERC1155Addr.toLowerCase() &&
      erc1155Instance) ||
    (contractAddress.toLowerCase() === ERC721Addr.toLowerCase() &&
      erc721Instance);
  // await getOfferByTimestamp(contractAddress, tokenId, createdBy, startTime);
  const isApproved = await instance.methods
    .isApprovedForAll(userAddr, MarketplaceAddr)
    .call();
  console.log("daisApprovedta1", isApproved);

  if (!isApproved) {
    const data1 = await instance.methods
      .setApprovalForAll(MarketplaceAddr, true)
      .encodeABI();
    console.log("data1", data1);
    await signTransaction(data1, userAddr, contractAddress, 0, userPK);
  }

  const data = await marketplaceInstance.methods
    .acceptOffer(contractAddress, createdBy, tokenId, startTime)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    userAddr,
    MarketplaceAddr,
    0,
    userPK
  );
  console.log("accept", receipt);
};

/**
 * start bidding
 *
 */
const bid = async (
  userAddr,
  userPK,
  contractAddress,
  tokenId,
  itemOwner,
  bidPrice
) => {
  const data = await marketplaceInstance.methods
    .bid(contractAddress, tokenId, itemOwner)
    .encodeABI();
  const receipt = await signTransaction(
    data,
    userAddr,
    MarketplaceAddr,
    bidPrice,
    userPK
  );

  console.log(receipt.logs);
  await getListing(contractAddress, itemOwner, tokenId);
};

const main = async () => {
  // await create721Token(user1Addr, user1PK);
  // await create1155Token(buyerAddr, 10, buyerPK);
  /** list for sale or hold/cancel
   *
   *
   * assetType-> 0:unknown,1: ERC721, 2:ERC1155
   * status-> 0: ONHOLD, 1:ONSALE
   * assetType tokenId  status,numOfCopies,price,
   * **/
  // await listToken(
  //   user1Addr,
  //   user1PK,
  //   ERC721Addr,
  //   1, //assetType
  //   1, //tokenId
  //   1, //status
  //   1, //num of copies
  //   web3.utils.toWei("0.5", "ether")
  // );
  // await getListing(ERC721Addr, user1Addr, 1); //public function
  /** buy
   * token, numOfCopies, itemowner, contractAddr price
   *
   */
  // await buyListing(
  //   buyerAddr,
  //   buyerPK,
  //   1,
  //   1,
  //   user1Addr,
  //   ERC721Addr,
  //   web3.utils.toWei("1", "ether")
  // );
  // await batchBuy(
  //   buyerAddr,
  //   buyerPK,
  //   [5, 6],
  //   [1, 1],
  //   [user1Addr, user1Addr],
  //   [ERC721Addr, ERC721Addr],
  //   web3.utils.toWei("1.5", "ether")
  //);
  // for (let i = 0; i < 2; i++) {
  //   await create721Token(user1Addr, user1PK);
  // }
  // await makeOffer(
  //   buyerAddr,
  //   buyerPK,
  //   ERC721Addr,
  //   1, //assetype
  //   1, //tokenid
  //   1, //num of copies
  //   web3.utils.toWei("0.5", "ether"),
  //   false,
  //   [],
  //   [],
  //   user1Addr
  // );
  // await getAllOffers();
  // await acceptOffer(user1Addr, user1PK, ERC721Addr, buyerAddr, 1, 1675785430);
  // await getOfferByTimestamp(ERC721Addr, 1, buyerAddr, 1675785430);
  // await withdrawOutstandingPayment(user1Addr, user1PK);
  // await checkUserRoyalty(1);
  // const owner = await erc721Instance.methods.ownerOf(1).call();
  await getOutstandingBalance(buyerAddr);
  // const owner = await erc721Instance.methods.tokenCreator(1).call();
  // const owner = await marketplaceInstance.methods.commissionReceiver().call();
  // const owner = await erc721Instance.methods
  //   .setApprovalForAll(MarketplaceAddr, true)
  //   .encodeABI();
  // const send = await signTransaction(owner,)
  // console.log(owner);

  //   await bid(
  //     buyerAddr2,
  //     buyerPK2,
  //     ERC721Addr,
  //     1,
  //     user1Addr,
  //     web3.utils.toWei("0.6", "ether")
  //   );
};
main()
  .then((_) => {})
  .catch((err) => console.log(err));

//await market.batchBuy([,3],[1,1],[user,user],[erc721.address,erc721.address],{from:buyer,value:web3.utils.toWei('2','ether')})
