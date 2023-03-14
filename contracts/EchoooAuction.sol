// SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import './interfaces/IDelegate.sol';
import "./interfaces/IERC2981.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC1155.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
// import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {
    Order,Input,Status,Side,Settle,
    BidListing721,
    BidListing1155,
    PaymentType,Fee
} from "./lib/OrderStruct.sol";
contract EchoooAuction is 
    ReentrancyGuard,
    Ownable,
    Pausable
{
    using SafeERC20 for IERC20;
    // enum WayType { Seconds, Minute}

    mapping(address => mapping(uint256 => mapping(address => BidListing721))) private _bidlisting721s;
    mapping(address => mapping(uint256 => mapping(address => BidListing1155))) private _bidlisting1155s;
    mapping(address => uint256) public wallet;
    mapping(address => bool) public delegates;
    mapping(bytes32 => Status) public orderStatus;
    event EventOrderCancel(bytes32 indexed orderHash);
    event EventUpdateDelegate(address indexed delegate, bool indexed isRemoval);
    event EventHighestBidIncreased(uint256, address, address, uint256);
    event EventPaymentTransfered(
        bytes32 indexed orderHash, 
        address currency, 
        address indexed seller, 
        uint indexed amount
    );
    event EventOrderComplete(
        bytes32 orderHash,
        address tokenAddress,
        address user,
        uint256 side, 
        uint delegateType,
        uint tokenId,
        uint amount,
        address currencyAddress,
        uint256 price,
        bool offerTokens,
        address[] offerTokenAddress,
        uint256[] offerTokenIds,
        Settle settle
    );

    uint256 FEE_DENOMINATOR = 10000;
    uint256 paymentReceiverFee;
    address public paymentReceiver;

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    constructor(address _paymentReceiver,uint256 _paymentReceiverFee) {
        paymentReceiver = _paymentReceiver;
        paymentReceiverFee = _paymentReceiverFee;
    }

    //update paymentReceiverAddress
    function updatePaymentReceiverAndFee(address _paymentReceiver, uint256 _prFeeCap) external onlyOwner {
        paymentReceiver = _paymentReceiver;
        paymentReceiverFee = _prFeeCap;
    }
  
    function updateDelegates(address[] memory toAdd, address[] memory toRemove)
        public
        virtual
        onlyOwner
    {
        for (uint256 i = 0; i < toAdd.length; i++) {
            delegates[toAdd[i]] = true;
            emit EventUpdateDelegate(toAdd[i], false);
        }
        for (uint256 i = 0; i < toRemove.length; i++) {
            delete delegates[toRemove[i]];
            emit EventUpdateDelegate(toRemove[i], true);
        }
    }
    function cancel(
        Order memory order,
        uint endTime,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant whenNotPaused{
        require(endTime > block.timestamp, 'deadline reached');
        
        bytes32 orderHash = _hashOrder(order);
        require(
            order.status == Status.NEW && 
            orderStatus[orderHash] == Status.NEW,
            'Auction:order already exist'
        );
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(orderHash), v, r, s);
        require(signer == order.user, 'Input signature error');
        orderStatus[orderHash] = Status.CANCELED;
        emit EventOrderCancel(orderHash);
    }
    //english auction supports only ETH - as per sample code provided
    function englishAuctionERC721Bid(Order memory order,uint256 _price, bytes32 orderHash) external payable{
        //check for seller's signature
        _verifyOrderSignature(order);
        //check for conditions
        require(order.status == Status.AUCTION && orderStatus[orderHash] == Status.NEW,'Auction:order already exist');
        require(Side(order.side) == Side.AUCTION, 'invalid side');
        require(
            address(order.executionDelegate) != address(0) && 
            delegates[address(order.executionDelegate)],
            'Auction:invalid delegateAddress'
        );
        require(
            order.executionDelegate.delegateType() == 1,
            'Auction:invalid delegation type'
        ); //ERC721
        address _owner = IERC721(order.tokenAddress).ownerOf(order.tokenId);
        require(_owner == order.user,'invalid token onwer');
        require(order.price > 0, "invalid auction start price");
        require(_price == msg.value,'price and msg.value not same');
         require(
            block.timestamp <= order.endTime &&
            block.timestamp >= order.startTime,
            "Auction not started/already ended."
        );
        //bid should be in native currency address
        require(_isNative(IERC20(order.currencyAddress)), 'settle only in ETH');
        
        //take a bid
        uint256 _highPrice = _bidlisting721s[order.tokenAddress][order.tokenId][_owner].highPrice;
        
        require(msg.value > order.price, "insufficient funds");
        require(msg.value > _highPrice, 'there is already a higher bid');

        if(_highPrice != 0){
            wallet[_bidlisting721s[order.tokenAddress][order.tokenId][_owner].currentBidder] += _bidlisting721s[order.tokenAddress][order.tokenId][_owner].highPrice;
        }
        _bidlisting721s[order.tokenAddress][order.tokenId][_owner] = BidListing721({
            highPrice: msg.value,
            currentBidder: msg.sender
        });
        emit EventHighestBidIncreased(order.tokenId,_owner,msg.sender,msg.value);
    }


    function englishAuctionERC1155Bid(Order memory order, uint tokenAmount, bytes32 orderHash) external payable {
        //check for seller's signature
        _verifyOrderSignature(order);
        //check for conditions
        require(order.status == Status.AUCTION && orderStatus[orderHash] == Status.NEW,'Auction:order already exist');
        require(Side(order.side) == Side.AUCTION, 'invalid side');
        require(
            address(order.executionDelegate) != address(0) && 
            delegates[address(order.executionDelegate)],
            'Auction:invalid delegateAddress'
        );
        require(
            order.executionDelegate.delegateType() == 2,
            'Auction:invalid delegation type'
        ); //ERC1155

        uint256 balance = IERC1155(order.tokenAddress).balanceOf(order.user, order.tokenId);
        require(balance >= 1, 'insufficient number of copies');
        require(order.amount == tokenAmount, 'incorrect token amount');
        require(order.price > 0, "invalid auction start price");
         require(
            block.timestamp <= order.endTime &&
            block.timestamp >= order.startTime,
            "Auction not started/already ended."
        );
        //bid should be in native currency address
        require(_isNative(IERC20(order.currencyAddress)), 'settle only in ETH');

        //take a bid
        uint256 _highPrice = _bidlisting1155s[order.tokenAddress][order.tokenId][order.user].highPrice;
        require(msg.value > order.price, "insufficient funds");
        require(msg.value > _highPrice, 'there is already a higher bid');
        if(_highPrice != 0){
            wallet[_bidlisting1155s[order.tokenAddress][order.tokenId][order.user].currentBidder] += _bidlisting1155s[order.tokenAddress][order.tokenId][order.user].highPrice;
        }
        _bidlisting1155s[order.tokenAddress][order.tokenId][order.user] = BidListing1155({
            amount:order.amount,
            highPrice: msg.value,
            currentBidder: msg.sender
        });
        emit EventHighestBidIncreased(order.tokenId,order.user,msg.sender,msg.value);
    }

    //settled by buyer or highestBidder, (msg.sedner is buyer), (order.user is seller)
    function englishAuctionBuy(Input memory input, bytes32 orderHash) public {
        Order memory order = input.orders[0];
         //check for seller's signature
        _verifyOrderSignature(order);
        _verifyInputSignature(input);
        require(Side(order.side) == Side.AUCTION, 'invalid side');
        require(msg.sender == input.settle.user, 'Auction:invalid caller');
        require(block.timestamp > order.endTime,"Auction end: auction not yet ended");
        require(order.status == Status.AUCTION && orderStatus[orderHash] == Status.NEW,'Auction:order already exist');
        require(_isNative(IERC20(order.currencyAddress)), 'settle only in ETH');
        require(
            address(order.executionDelegate) != address(0) && 
            delegates[address(order.executionDelegate)],
            'Auction:invalid delegateAddress'
        );
        uint256 highestBidPrice =0;
        orderStatus[orderHash] = Status.COMPLETE;
        if(order.executionDelegate.delegateType() == 1){//if 721
            address _owner = IERC721(order.tokenAddress).ownerOf(order.tokenId);
            require(_owner == order.user, 'invalid token owner');
            BidListing721 memory bidList =_bidlisting721s[order.tokenAddress][order.tokenId][_owner];
            
            require(bidList.highPrice > order.price,'bid price needs > startPrice');
            require(bidList.currentBidder == msg.sender , "Can't buy for others");
            //token transfer
            highestBidPrice = bidList.highPrice;
            require(
                order.executionDelegate.executeBuy(order.tokenAddress, order.user,msg.sender,order.tokenId,order.amount,'AUCTION'),
                'delegation error'
            );
        }
        if(order.executionDelegate.delegateType() == 2){//if 1155
            uint256 balance = IERC1155(order.tokenAddress).balanceOf(order.user, order.tokenId);
            require(balance >= 1, 'inufficient token amount');
            BidListing1155 memory bidList =_bidlisting1155s[order.tokenAddress][order.tokenId][order.user];
        
            require(bidList.highPrice > order.price,'bid price needs > startPrice');
            require(bidList.currentBidder == msg.sender , "Can't buy for others");
            //token transfer
            highestBidPrice = bidList.highPrice;
            require(
                order.executionDelegate.executeBuy(order.tokenAddress, order.user,msg.sender,order.tokenId,order.amount,'AUCTION'),
                'delegation error'
            );
        }
        (address royaltyAddr,uint256 royaltyAmount) = IERC2981(order.tokenAddress).royaltyInfo(order.tokenId, highestBidPrice);
        uint256 commissionFee = (highestBidPrice * paymentReceiverFee) / FEE_DENOMINATOR;
        wallet[royaltyAddr] += royaltyAmount;
        wallet[paymentReceiver] += commissionFee;
        wallet[order.user] += highestBidPrice - commissionFee - royaltyAmount;
        _emitEventOrderComplete(orderHash,order,input.settle);
    }



    // this is call by the buyer
    function DutAuctionBuy(Input memory input) public payable{

        //get order
        Order memory order = input.orders[0];

        //check for both party signatures
        _verifyOrderSignature(order);
        _verifyInputSignature(input);

        bytes32 orderHash = _hashOrder(order);

        require(order.status == Status.AUCTION && orderStatus[orderHash] == Status.NEW,'Auction:order already exist');
        require(order.startTime <= block.timestamp &&  block.timestamp<= order.endTime, "Auction: time error");
        require(msg.sender == input.settle.user, 'Auction:invalid caller');
        require(input.settle.deadline > block.timestamp, 'Auction: settle deadline reached');

        require(address(order.executionDelegate) != address(0) && delegates[address(order.executionDelegate)],
            'Marketplace:invalid delegateAddress'
        );

        uint256 _timeElapsed = block.timestamp - order.startTime;
        uint256 _discountRate = (order.price - order.lowestPrice) / _timeElapsed ;
        uint256 discount = _discountRate * _timeElapsed;
        uint256 _price = order.price - discount; //settlement price (all protocol fee, royalty gonna deduct from this price)

        if(_isNative(IERC20(order.currencyAddress))) {
            //check for bidding price
            require(msg.value >= _price, "amount should be greater than price of token");
        }
        orderStatus[orderHash] = Status.COMPLETE;
        uint amount = _takePayment(IERC20(order.currencyAddress),order.user, _price);
        if(order.executionDelegate.delegateType() == 1){//if 721
            address _owner = IERC721(order.tokenAddress).ownerOf(order.tokenId);
            require(_owner == order.user, 'invalid token owner');
            require(
                order.executionDelegate.executeBuy(order.tokenAddress, order.user,msg.sender,order.tokenId,order.amount,'AUCTION'),
                'delegation error'
            );

        }
        if(order.executionDelegate.delegateType() == 2){//if 1155
            uint256 balance = IERC1155(order.tokenAddress).balanceOf(order.user, order.tokenId);
            require(balance >= 1, 'inufficient token amount');
            require(
                order.executionDelegate.executeBuy(order.tokenAddress, order.user,msg.sender,order.tokenId,order.amount,'AUCTION'),
                'delegation error'
            );
        }
        
        _distributeFeeAndProfit(
            orderHash, //
            order.user, //seller
            IERC20(order.currencyAddress), //currencyaddress
            _price,
            order.tokenAddress,
            order.tokenId,
            order.fee
        );  //转账

        if(amount > 0){
            uint refund = msg.value - amount;
            if(refund > 0) {payable(msg.sender).transfer(refund);}
        }
        _emitEventOrderComplete(orderHash,order,input.settle);
    }


    function withDraw() external{
        payable(msg.sender).transfer(wallet[msg.sender]);
    }

    //internal
    function _transferTo(
        IERC20 currency,
        address to,
        uint256 amount
    ) internal virtual {
        if (amount > 0) {
            if (_isNative(currency)) {
                Address.sendValue(payable(to), amount);
            } else {
                currency.safeTransfer(to, amount);
            }
        }
    }
    function _transferCommissionFee() internal returns(uint256){
        
    }
    function _distributeFeeAndProfit(
        bytes32 orderHash,
        address seller, 
        IERC20 currency, 
        uint256 price,
        address tokenAddress,
        uint256 tokenId,
        Fee[] memory fee
    ) internal {
        require(price > 0, 'invalid transfer amount');
        uint256 totalFee = 0;
        //marketplace fee
        if(paymentReceiver != address(0)){
            uint256 prFee = (price * paymentReceiverFee) / FEE_DENOMINATOR;
            totalFee += prFee;
            _transferTo(currency, paymentReceiver, prFee);
            price -= prFee;
        }
        (address royaltyAddr,uint256 royaltyAmount) = IERC2981(tokenAddress).royaltyInfo(tokenId, price);
        if(royaltyAmount > 0 && royaltyAddr != address(0)) {
            totalFee += royaltyAmount;
            _transferTo(currency, royaltyAddr, royaltyAmount);
            price -= royaltyAmount;
        }
        for(uint8 i=0; i<fee.length; i++){
            uint256 feeAmount = (price * fee[i].percentage) / FEE_DENOMINATOR;
            totalFee += feeAmount;
            _transferTo(currency, fee[i].to, feeAmount);
            price -= feeAmount;
        }
        require(price >= totalFee,'Total amount of fees are more than the price');
        _transferTo(currency, seller, price);
        emit EventPaymentTransfered(orderHash,address(currency),seller,price);
    }
    function _takePayment(IERC20 currency,address from, uint amount) internal returns(uint256){
        if(amount > 0){
            if(_isNative(currency)){
                return amount;
            }else{
                currency.safeTransferFrom(from, address(this), amount);
            }
        }
        return 0;
    }
    function _isNative(IERC20 currency) internal view virtual returns (bool) {
        return address(currency) == address(0);
    }
    function _hashOrder(Order memory order) internal pure returns(bytes32){
        return keccak256(
            abi.encode(
                order.salt,
                order.user,
                order.side,
                order.delegateType,
                order.amount,
                order.tokenId
            )
        );
    }
    function _verifyInputSignature(Input memory input) internal pure returns(bool){
        bytes32 inputHash = keccak256(abi.encode(input.settle, input.orders.length));
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(inputHash), input.v, input.r, input.s);
        require(signer == input.settle.user,'Marketplace: invalid input signature');
        return true;
    }
    function _verifyOrderSignature(Order memory order) internal pure returns(bool){
        bytes32 orderHash = keccak256(
            abi.encode(
                order.salt,
                order.user,
                order.side,
                order.delegateType,
                order.amount,
                order.tokenId
            )
        );
        address orderSigner = ECDSA.recover(ECDSA.toEthSignedMessageHash(orderHash), order.v, order.r, order.s);
        require(orderSigner == order.user,'Auction: invalid order signature');
        return true;
    }
    function _emitEventOrderComplete(bytes32 _orderHash,Order memory order, Settle memory settle) internal {
        emit EventOrderComplete(
            _orderHash,
            order.tokenAddress,
            order.user,
            order.side,
            order.delegateType,
            order.tokenId,
            order.amount,
            order.currencyAddress,
            order.price,
            order.offerTokens,
            order.offerTokenAddress,
            order.offerTokenIds,
            settle);
    }

}