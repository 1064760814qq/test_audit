// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IDelegate.sol';
import "./interfaces/IERC2981.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
// import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import {Order, Status,Side,Settle,Input,Fee,PaymentType} from "./lib/OrderStruct.sol";

contract EchoooMarketplace is 
    ReentrancyGuard,
    Ownable,
    Pausable
{
    using SafeERC20 for IERC20;
    mapping(address => bool) public delegates;
    mapping(bytes32 => Status) public orderStatus;
    mapping(address => mapping(address => mapping(uint256 => mapping(uint256 => address)))) private tokenKeeper;
    event EventOrderCancel(bytes32 indexed orderHash);
    event EventUpdateDelegate(address indexed delegate, bool indexed isRemoval);
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
    address public escrowAddress;

    receive() external payable {}

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    constructor(address _paymentReceiver, address _escrowAddress,uint256 _paymentReceiverFee) {
        paymentReceiver = _paymentReceiver;
        escrowAddress = _escrowAddress;
        paymentReceiverFee = _paymentReceiverFee;
    }
    // function initialize() public initializer {        

    //     __ReentrancyGuard_init_unchained();
    //     __Pausable_init_unchained();
    //     __Ownable_init_unchained();
    // }

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
            'Marketplace:order already exist'
        );
        address signer = ECDSA.recover(ECDSA.toEthSignedMessageHash(orderHash), v, r, s);
        require(signer == order.user, 'Input signature error');
        orderStatus[orderHash] = Status.CANCELED;
        emit EventOrderCancel(orderHash);
    }

    function executeBuy(Input memory input) external payable nonReentrant whenNotPaused {
        require(_checkDeadlineAndCaller(input.settle.user, input.settle.deadline));
        _verifyInputSignature(input);

        for (uint256 i = 0; i < input.orders.length; i++) {
            _verifyOrderSignature(input.orders[i]);
            //transfer token to admin 
            if(PaymentType(input.settle.paymentType) == PaymentType.FIAT){
                _transferTokenToEscrow(input.orders[i]);
            }
        }
        uint256 amountPaid = msg.value;
        for(uint256 i=0; i < input.orders.length; i++){
            Order memory order = input.orders[i];

            if(Side(order.side) == Side.BUY){
                amountPaid -= _execute(order, input.settle);
            }else{ revert('unknown side');}
        }
        if (amountPaid > 0) {
            payable(msg.sender).transfer(amountPaid);
        }
    }
    function executeOffer(Input memory input) external payable nonReentrant whenNotPaused {
        require(_checkDeadlineAndCaller(input.settle.user, input.settle.deadline));
        _verifyInputSignature(input);
        for (uint256 i = 0; i < input.orders.length; i++) {
            _verifyOrderSignature(input.orders[i]);
        }
        uint256 amountPaid = msg.value;
        for(uint256 i=0; i < input.orders.length; i++){
            Order memory order = input.orders[i];
            if(Side(order.side) == Side.OFFER){
                amountPaid -= _execute(order, input.settle);
            }else{ revert('unknown side');}
        }
        if (amountPaid > 0) {
            payable(msg.sender).transfer(amountPaid);
        }
    }

    //update paymentReceiverAddress
    function updatePaymentReceiverAndFee(address _paymentReceiver, uint256 _prFeeCap) external onlyOwner {
        paymentReceiver = _paymentReceiver;
        paymentReceiverFee = _prFeeCap;
    }
    //update escrowAddress
    function updateEscrowAddress(address _escrowAddress) external onlyOwner {
        escrowAddress = _escrowAddress;
    }

    //internal functions
    function _execute(Order memory order, Settle memory settle) whenNotPaused internal returns(uint256){
        uint amount = 0;
            require(
                address(order.executionDelegate) != address(0) && 
                delegates[address(order.executionDelegate)],
                'Marketplace:invalid delegateAddress'
            );
            require(
                order.executionDelegate.delegateType() == order.delegateType,
                'Marketplace:invalid delegation type'
            );
        bytes32 orderHash = _hashOrder(order);
        if(Side(order.side) == Side.BUY){
            require(order.status == Status.NEW && orderStatus[orderHash] == Status.NEW,'Marketplace:order already exist');
            require(order.endTime > block.timestamp, 'Marketplace: order deadline reached');
            require(settle.price >= order.price , 'underpaid');
            require(
                order.tokenAddress == settle.tokenAddress,
                "Marketplace: order params are not same"
            );
            orderStatus[orderHash] = Status.COMPLETE;
            amount = _takePayment(IERC20(order.currencyAddress),settle.user, order.price);
            if(PaymentType(settle.paymentType) == PaymentType.FIAT){
                require(
                    tokenKeeper[order.tokenAddress][order.user][order.tokenId][order.amount] == escrowAddress,
                    'no token holdings in escrow'
                );
                require(order.executionDelegate.executeSell(order.tokenAddress,escrowAddress,settle.user, order.tokenId,order.amount,'SELL'),'delegate error');
            }
            else{
                require(order.executionDelegate.executeSell(order.tokenAddress,order.user,settle.user, order.tokenId,order.amount,'SELL'),'delegate error');
            }
            
            _distributeFeeAndProfit(
                orderHash, //
                order.user, //seller
                IERC20(order.currencyAddress), //currencyaddress
                order.price,
                order.tokenAddress,
                order.tokenId,
                order.fee
            );
        }else if(Side(order.side) == Side.OFFER){
            require(order.status == Status.NEW && orderStatus[orderHash] == Status.NEW,'Marketplace:order already exist');
            require(order.endTime > block.timestamp, 'Marketplace: order deadline reached');
            require(order.price == settle.price , 'offer price not same');
            require(!_isNative(IERC20(order.currencyAddress)), 'native token not supported');
            orderStatus[orderHash] = Status.COMPLETE;
            if(order.offerTokens && settle.acceptTokens && order.price == 0 && settle.price == 0){
                _executeTokenExchange(order, settle);
            }
            else{     
                require(settle.price >0 && order.price >0 , 'underpaid');
                require(
                    order.tokenAddress == settle.tokenAddress,
                    "Marketplace: order params are not same"
                );
                
                amount = _takePayment(IERC20(order.currencyAddress),order.user, order.price);
                if(order.offerTokens && settle.acceptTokens && order.price > 0 && settle.price > 0){
                    _executeTokenExchange(order, settle);
                }else{
                    require(
                        order.executionDelegate.executeBuy(order.tokenAddress, settle.user,order.user,order.tokenId,order.amount,'OFFER'),
                        'delegation error'
                    );
                }
                
                _distributeFeeAndProfit(
                    orderHash, //
                    settle.user, //user accepting offer
                    IERC20(order.currencyAddress), //currencyaddress
                    settle.price,
                    order.tokenAddress,
                    order.tokenId,
                    order.fee
                );
            }
        }
        else{
            revert('unknown side');
        }
        _emitEventOrderComplete(orderHash,order,settle);
        return amount;
    }
    function _executeTokenExchange(Order memory order, Settle memory settle) internal returns(bool){
        require(order.offerTokenAddress.length == order.offerTokenIds.length, 'length not same');

        for(uint256 i=0; i < order.offerTokenAddress.length; i++){
            require(
                order.executionDelegate.executeSell(order.offerTokenAddress[i], order.user,settle.user,order.offerTokenIds[i],order.amount,'OFFER'),
                'order delegation error'
            );
        }
        require(order.executionDelegate.executeBuy(settle.tokenAddress,settle.user, order.user,settle.tokenId,order.amount,'OFFER'),'settle delegation error');
        return true;
    }
    function _transferTokenToEscrow(Order memory order) internal whenNotPaused{
        tokenKeeper[order.tokenAddress][order.user][order.tokenId][order.amount] = escrowAddress; 
        require(order.executionDelegate.executeSell(
            order.tokenAddress,
            order.user, //from address
            escrowAddress, //to address
            order.tokenId,
            order.amount,
            'TRANSFER'),
            'transfer token to escrow addr error'
        );
    }
    function _isNative(IERC20 currency) internal view virtual returns (bool) {
        return address(currency) == address(0);
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
    function _inputHash(Input memory input) internal pure returns(bytes32){
        bytes32 inputHash = keccak256(abi.encode(input.settle, input.orders.length));
        return inputHash;
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
        require(orderSigner == order.user,'Marketplace: invalid order signature');
        return true;
    }
    function _checkDeadlineAndCaller(address settleUserAddress, uint256 settleDeadline) internal view returns (bool){
        require(msg.sender == settleUserAddress, 'Marketplace:invalid caller');
        require(settleDeadline > block.timestamp, 'Marketplace: settle deadline reached');
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