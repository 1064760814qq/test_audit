const ethers = require("ethers");
const ERC721ABI = require("../abis/EchoooERC721.json");
const ERC1155ABI = require("../abis/EchoooERC1155.json");
const MarketplaceABI = require("../abis/EchoooMarketplace.json");
const ERC721DelegateABI = require("../abis/ERC721Delegate.json");
const ERC1155DelegateABI = require("../abis/ERC1155Delegate.json");

const ERC721Addr = "0x18C68B3adacE08C934408c343BC50a7EDe3F4aD7";
const ERC1155Addr = "0xE4469AD25d7d00360b67f8F04228e829dcc90dDc";
const MarketplaceAddr = "0x6B885a91B85D57C130506E952C700c844Cc969c3";
const ERC721Delegate = "0xdefD66186107b38B7070C99703AB71Ef98530B6B";
const ERC1155Delegate = "0x634F538186e860e64F366452AA3eA3AFDb9e79ca";
const MockWeth = "0x738C632B25D40d99fCbC4603c85422bE170Bb2Cb";

const sellerAddr = "0xBF64B440DB2B84166612824876cc4a20af0476AA";
const sellerPK =
  "9880e4d682f9afdf98fea01c1313232fdc460a5176519a6e464fea54aa78cfe2";

const buyerAddr = "0x61bBFc3CAeD73612348aa118c5b9200768325bAe";
const buyerPK =
  "ff672c13f395bdd3b36c8e02aa6c355d0a9f52a9f9edbf2a36b38dfebfdbc925";

const buyerAddr2 = "0xe47d48A6313D28c49aA424c318Aeb2c48e91B296";
const buyerPK2 =
  "643c6fffec1dc888983a6ac55c6fd5e6c57aed0b965744b8a99f07d6342ac42e";

const url = "https://goerli.infura.io/v3/511db41b27f84f4497676adb7905871f";
const provider = new ethers.providers.JsonRpcProvider(url);
const admin = new ethers.Wallet(sellerPK, provider);
const seller = new ethers.Wallet(sellerPK, provider);
const buyer = new ethers.Wallet(buyerPK, provider);

const erc721instance = new ethers.Contract(ERC721Addr, ERC721ABI, provider);
const erc1155instance = new ethers.Contract(ERC1155Addr, ERC1155ABI, provider);
const marketplaceinstance = new ethers.Contract(
  MarketplaceAddr,
  MarketplaceABI,
  provider
);
const erc721Delegate = new ethers.Contract(
  ERC721Delegate,
  ERC721DelegateABI,
  provider
);
const erc1155Delegate = new ethers.Contract(
  ERC1155Delegate,
  ERC1155DelegateABI,
  provider
);

module.exports = {
  admin,
  seller,
  buyer,
  erc721instance,
  erc1155instance,
  marketplaceinstance,
  erc721Delegate,
  erc1155Delegate,
};
