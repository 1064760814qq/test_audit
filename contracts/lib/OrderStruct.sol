// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import '../interfaces/IDelegate.sol';

enum Side { BUY, OFFER, AUCTION }
enum AssetType {UNKNOWN, ERC721, ERC1155 }
enum Status {NEW, COMPLETE, CANCELED, AUCTION}
enum PaymentType {CRYPTO, FIAT}

struct Fee {
    uint16 percentage;
    address to;
}

struct Order {
    uint256 salt;
    address tokenAddress;
    address user;
    uint256 side; //order type
    uint delegateType; //delegate type
    uint tokenId;
    uint amount; //number of copies
    IDelegate executionDelegate;
    address currencyAddress;
    uint256 price;
    uint256 startTime;
    uint256 endTime;
    bool offerTokens;
    address[] offerTokenAddress;
    uint256[] offerTokenIds;
    Fee[] fee;
    //signature
    bytes32 r;
    bytes32 s;
    uint8 v;
    Status status;
    uint256 lowestPrice;

}
struct Settle {
    uint256 salt;
    address tokenAddress;
    uint tokenId;
    uint amount;
    uint256 deadline;
    uint delegateType; //delegate type
    address user; //who wants to settle the order
    uint256 price;
    bool acceptTokens;
    bool completed;
    PaymentType paymentType; //0: CRYPTO, 1:FIAT
}
struct Input {
    Order[] orders;
    Settle settle;
    //signature
    bytes32 r;
    bytes32 s;
    uint8 v;
}

//AUCTION structs

struct BidListing721 {
    uint256 highPrice;
    address currentBidder;
}

struct BidListing1155 {
    uint256 amount;
    uint256 highPrice;
    address currentBidder;
}