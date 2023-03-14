// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
interface IERC1155 {
  function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data, string memory txType) external;
  function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data, string memory txType) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
  function balanceOf(address _owner, uint256 _id) external view returns (uint256);
  function setApprovalForAll(address operator, bool _approved) external;
  function isApprovedForAll(address account, address operator) external view returns (bool);
  function tokenRoyalty(uint256 _id) external view returns (uint256);
}

interface IERC721 {
  function transferFrom(address _from, address _to, uint256 _tokenId) external;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, string memory txType) external;
  function safeTransferFrom(address _from, address _to, uint256 _tokenId, uint256 _value, bytes calldata _data,string memory txType) external;
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
  function balanceOf(address _owner) external view returns (uint256);
  function ownerOf(uint256 _tokenId) external view returns (address);
  function setApprovalForAll(address operator, bool approved) external;
  function tokenRoyalty(uint256 _id) external view returns (uint256);
  function isApprovedForAll(address owner, address operator) external view returns (bool);
}
interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
contract AlvinMarketplace {

    enum AssetType { UNKNOWN, ERC721, ERC1155 }
    enum ListingStatus { ON_HOLD, ON_SALE, ON_AUCTION}

    struct Listing {
        address contractAddress;
        AssetType assetType;
        ListingStatus status;
        uint numOfCopies;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
        uint256 highestBid;
    }
    struct Offer {
        address contractAddress;
        address createdByAddress;
        AssetType assetType;
        uint numOfCopies;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        bool typeNFT;
        address[] offeredTokenAddress;
        uint[] offeredTokenId;
        bool accepted;
    }
    address admin;
    uint256 private _defaultCommission;
    address private _commissionReceiver;
    // bool anyoneMakeOffer;
    mapping(address => mapping(uint256 => mapping(address => Listing))) private _listings;
    mapping(address => mapping(uint => Offer[])) private _offerListing;
    mapping(address => mapping(uint => mapping(address => mapping(uint => Offer)))) private _sOfferListing;
    mapping(address => uint256) private _outstandingPayments;

    event PurchaseConfirmed(uint256 indexed tokenId, address indexed itemOwner, address indexed buyer);
    event PaymentWithdrawn(uint256 indexed amount);
    event HighestBidIncreased(uint256 indexed tokenId,address itemOwner,address indexed bidder,uint256 indexed amount);
    event OfferAccepted(address indexed contractAddress, address indexed createdByAddress, uint indexed tokenId);
    event TransferCommission(address indexed reciever, uint indexed tokenId, uint indexed value);
    event TransferRoyalty(address indexed receiver, uint indexed tokenId, uint indexed value);
    event AuctionEnded(uint256 tokenId,address itemOwner,address winner,uint256 amount);

    constructor(address _admin, address _cr) {
        admin = _admin;
        _commissionReceiver = _cr;
        _defaultCommission = 2500;
    }
    modifier _isAdmin{
        require(admin == msg.sender, "Marketplace:Caller is not an admin");
        _;
    }
    modifier _isType(AssetType _assetType){
        require(
            _assetType == AssetType.ERC721 || _assetType == AssetType.ERC1155,
            "Only ERC721/ERC1155 are supported"
        );
        _;
    }
    function commissionReceiver() external view returns (address) {
        return _commissionReceiver;
    }

    function setCommissionReceiver(address user) _isAdmin external {
        _commissionReceiver = user;
    }

    function defaultCommission() external view returns (uint256) {
        return _defaultCommission;
    }
    function setDefaultCommission(uint256 commission) _isAdmin external {
        require(commission <= 30000, "commission is too high");
        _defaultCommission = commission;
    }
    function updateAdmin(address _newAdmin)  external _isAdmin {
        admin = _newAdmin;
    }
    function setListing(
        address _contractAddress, 
        AssetType _assetType,
        uint _tokenId,
        ListingStatus _status,
        uint _numOfCopies,
        uint _price,
        uint256 _startTime,
        uint256 _endTime) _isType(_assetType) external {
        
        _checkTypeAndBalance(_assetType, _contractAddress, _tokenId, _numOfCopies);

        if (_status == ListingStatus.ON_HOLD) {
            require(
                _listings[_contractAddress][_tokenId][msg.sender].highestBidder == address(0),
                "Marketplace: bid already exists"
            );

            _listings[_contractAddress][_tokenId][msg.sender] = Listing({
                contractAddress: _contractAddress,
                assetType: _assetType,
                status: _status,
                numOfCopies:0,
                price: 0,
                startTime: 0,
                endTime: 0,
                highestBidder: address(0),
                highestBid: 0
            });
        } else if (_status == ListingStatus.ON_SALE) {
            require(
                _listings[_contractAddress][_tokenId][msg.sender].status == ListingStatus.ON_HOLD,
                "Marketplace: token not on hold"
            );

            _listings[_contractAddress][_tokenId][msg.sender] = Listing({
                contractAddress: _contractAddress,
                assetType: _assetType,
                status: _status,
                numOfCopies:_numOfCopies,
                price: _price,
                startTime: 0,
                endTime: 0,
                highestBidder: address(0),
                highestBid: 0
            });
        }else if(_status == ListingStatus.ON_AUCTION){
            require(
                _listings[_contractAddress][_tokenId][msg.sender].status == ListingStatus.ON_HOLD,
                "Marketplace: token not on hold"
            );
            require(
                block.timestamp < _startTime && _startTime < _endTime,
                "endTime should be > startTime. startTime should be > current time"
            );

            _listings[_contractAddress][_tokenId][msg.sender] = Listing({
                contractAddress: _contractAddress,
                assetType: _assetType,
                status: _status,
                numOfCopies:_numOfCopies,
                price: _price,
                startTime: _startTime,
                endTime: _endTime,
                highestBidder: address(0),
                highestBid: 0
            });
        }        
    }

    function listingOf(address _contractAddress, address _account, uint256 _tokenId)
        external
        view
        returns (Listing memory)
    {
        require(_account != address(0),"Marketplace: address cannot be zero address");
        return _listings[_contractAddress][_tokenId][_account];
    }

    function buy(uint256 _tokenId, uint _numOfCopies,address _itemOwner, address _contractAddress, bool batch, uint _tokenPrice) public payable {
        uint tokenPrice = 0;
        bool isERC2981 = false;
        if(batch){tokenPrice = _tokenPrice;}
        else{ tokenPrice = msg.value;}

        require(
            _listings[_contractAddress][_tokenId][_itemOwner].status == ListingStatus.ON_SALE,
            "Marketplace: token not listed for sale"
        );
        //check balance and number of copies
        if (_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC721) {
            require(
                IERC721(_contractAddress).balanceOf(_itemOwner) > 0,
                "buy: Insufficient Copies to buy"
            );
            require(tokenPrice >= _listings[_contractAddress][_tokenId][_itemOwner].price*1, "buy721: not enough fund");
        } else if(_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC1155) {
            require(
                IERC1155(_contractAddress).balanceOf(_itemOwner, _tokenId) >= _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies,
                " buy: Insufficient Copies to buy"
            );
            require(
                _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies>=_numOfCopies,
                " buy: Insufficient Copies to buy"
            );
            require(tokenPrice >= _numOfCopies * _listings[_contractAddress][_tokenId][_itemOwner].price, "buy1155: not enough fund");
        }
        //calculates the commision
        //safeTransferFrom
        uint copiesLeft = 0;
        address ownerRoyaltyAddr;
        uint ownerRoyaltyAmount;
        if (_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC721) {
            IERC721(_contractAddress).safeTransferFrom(_itemOwner, msg.sender, _tokenId, "BUY");
            isERC2981 = IERC721(_contractAddress).tokenRoyalty(_tokenId) > 0 ? true:false;
        } else if(_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC1155) {
            IERC1155(_contractAddress).safeTransferFrom(_itemOwner, msg.sender, _tokenId, _numOfCopies, "","BUY");
            isERC2981 = IERC1155(_contractAddress).tokenRoyalty(_tokenId) > 0 ? true:false;
            copiesLeft = _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies - _numOfCopies;
        }
        if(isERC2981) {
            (ownerRoyaltyAddr,ownerRoyaltyAmount) = IERC2981(_contractAddress).royaltyInfo(_tokenId, msg.value);
        }
         _listings[_contractAddress][_tokenId][_itemOwner] = Listing({
            contractAddress: copiesLeft >= 1 ? _contractAddress : address(0),
            assetType: copiesLeft >= 1 ? _listings[_contractAddress][_tokenId][_itemOwner].assetType : AssetType.UNKNOWN,
            status: copiesLeft >= 1 ? _listings[_contractAddress][_tokenId][_itemOwner].status : ListingStatus.ON_HOLD,
            numOfCopies: copiesLeft >= 1 ? copiesLeft : 0,
            price: copiesLeft >= 1 ? _listings[_contractAddress][_tokenId][_itemOwner].price : 0,
            startTime: 0,
            endTime: 0,
            highestBidder: address(0),
            highestBid: 0
        });
        
        _outstandingPayments[_commissionReceiver] += ((msg.value * _defaultCommission) / 10000);
        _outstandingPayments[_itemOwner] += (msg.value - ((msg.value * _defaultCommission) / 10000));
        _outstandingPayments[ownerRoyaltyAddr] += ownerRoyaltyAmount;
        
        emit PurchaseConfirmed(_tokenId, _itemOwner, msg.sender);
    }
    
    function batchBuy(uint256[] memory _tokenId, uint[] memory _numOfCopies, address[] memory _itemOwner, address[] memory _contractAddress) external payable {
        require(_tokenId.length == _numOfCopies.length, 'Marketplace:Uint length dont match');
        require(_itemOwner.length == _contractAddress.length, 'Marketplace:addresses length dont match');
        uint totalPrice = 0;
        uint tokenPrice = msg.value;
        for (uint i=0;i <_tokenId.length; ++i){
           totalPrice = totalPrice+ _listings[_contractAddress[i]][_tokenId[i]][_itemOwner[i]].price;
        }
        require(msg.value>=totalPrice,'BatchBuy: Insuffiecient Funds');
        for(uint i = 0; i < _tokenId.length; ++i){
            buy(_tokenId[i], _numOfCopies[i], _itemOwner[i], _contractAddress[i], true, tokenPrice);
            tokenPrice = msg.value - _listings[_contractAddress[i]][_tokenId[i]][_itemOwner[i]].price;
        }
    }
    // function makeOfferNFT() external payable returns(OfferNFT memory){}
    function makeOffer( 
        address _contractAddress,
        AssetType _assetType,
        uint _tokenId,
        uint256 _startTime,
        uint256 _endTime, bool _typeNFT, 
        address[] memory _offeredTokenAddress, 
        uint[] memory _offeredTokenId, address _itemOwner) _isType(_assetType) external payable {
        
        require(_startTime > 0, 'Marketplace:Offer startTime must be > 0');
        require(_endTime > 0, 'Marketplace:Offer endTime must be > 0');
        require(
            _listings[_contractAddress][_tokenId][_itemOwner].status == ListingStatus.ON_SALE,
            "Marketplace: token not listed for sale"
        );
        uint _numOfCopies = _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies;
        if(_typeNFT && msg.value == 0){
            require(_offeredTokenAddress.length == _offeredTokenId.length, 'Marketplace: offered addr & token length doesnot match');
            _checkBalanceAndOwnership(_assetType,_offeredTokenAddress,_offeredTokenId, _numOfCopies);

        }else if(_typeNFT && msg.value > 0){
            require(msg.value > 0, 'Marketplace: offer amount > 0');
            require(_offeredTokenAddress.length == _offeredTokenId.length, 'Marketplace: offered addr & token length doesnot match');
            _checkBalanceAndOwnership(_assetType,_offeredTokenAddress,_offeredTokenId,_numOfCopies);
        }
        else{
            require(msg.value > 0, 'Marketplace: offer amount > 0');
        }
        _sOfferListing[_contractAddress][_tokenId][msg.sender][_startTime] = Offer({
            contractAddress: _contractAddress,
            createdByAddress: msg.sender,
            assetType: _assetType,
            numOfCopies: _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies,
            price: (_typeNFT && msg.value==0) ? 0 : (_typeNFT && msg.value>0) ? msg.value : msg.value,
            startTime: _startTime,
            endTime: _endTime,
            typeNFT: _typeNFT ? true: false,
            offeredTokenAddress: _offeredTokenAddress.length>0 ? _offeredTokenAddress : new address[](0),
            offeredTokenId: _offeredTokenId.length > 0 ? _offeredTokenId : new uint[](0),
            accepted: false
            }); 
        _offerListing[_contractAddress][_tokenId].push(_sOfferListing[_contractAddress][_tokenId][msg.sender][_startTime]);
        _outstandingPayments[msg.sender] += msg.value;
    }

    function acceptOffer(address _contractAddress, address _createdByAddress, uint _tokenId, uint _startTime) external {
        Offer storage _off = _sOfferListing[_contractAddress][_tokenId][_createdByAddress][_startTime];
        address ownerRoyaltyAddr;uint ownerRoyaltyAmount;
        bool isERC2981 = false;
        require(_off.accepted == false,'Marketplace: Offer is accepted already');
        require(block.timestamp <= _off.endTime && block.timestamp >= _off.startTime, 'Marketplace: Offer is expired');
        require(_off.offeredTokenAddress.length == _off.offeredTokenId.length, 'Marketplace: offered addr & token length doesnot match');
        
        if(_off.typeNFT && _off.price == 0){
            _checkOfferTypeAndTransfer(_off, _tokenId);
        }
        else{
            require(_outstandingPayments[_off.createdByAddress] >= _off.price,'Marketplace: User has insufficient funds');
            
            if(_off.assetType == AssetType.ERC721){
                require(IERC721(_off.contractAddress).balanceOf(msg.sender) > 0,"Marketplace: Insufficient Balance");
                IERC721(_off.contractAddress).safeTransferFrom(msg.sender, _off.createdByAddress, _tokenId,"OFFER");
                isERC2981 = IERC721(_contractAddress).tokenRoyalty(_tokenId) > 0 ? true:false;
                if(_off.typeNFT){
                    for(uint i = 0; i<_off.offeredTokenAddress.length; i++){
                        IERC721(_off.offeredTokenAddress[i]).safeTransferFrom(_off.createdByAddress, msg.sender,_off.offeredTokenId[i],"OFFER");
                    }
                }
                  
            } else if(_off.assetType == AssetType.ERC1155) {
                require(IERC1155(_off.contractAddress).balanceOf(msg.sender, _tokenId) >= _off.numOfCopies,"Marketplace: Insufficient Balance");
                IERC1155(_off.contractAddress).safeTransferFrom(msg.sender, _off.createdByAddress, _tokenId, _off.numOfCopies, "","OFFER");
                isERC2981 = IERC1155(_contractAddress).tokenRoyalty(_tokenId) > 0 ? true:false;
                if(_off.typeNFT){
                    for(uint i = 0; i<_off.offeredTokenAddress.length; i++){
                        IERC1155(_off.offeredTokenAddress[i]).safeTransferFrom( _off.createdByAddress,msg.sender, _off.offeredTokenId[i], 1, "","OFFER");
                    }
                }
            }
        }
        _off.accepted = true;
        _offerListing[_contractAddress][_tokenId].push(_sOfferListing[_contractAddress][_tokenId][_createdByAddress][block.timestamp]);
        if(isERC2981){
            (ownerRoyaltyAddr,ownerRoyaltyAmount) = IERC2981(_contractAddress).royaltyInfo(_tokenId, _off.price);
        }
        if(_listings[_off.contractAddress][_tokenId][msg.sender].status == ListingStatus.ON_SALE){
            _listings[_off.contractAddress][_tokenId][msg.sender] = Listing(address(0),AssetType.UNKNOWN,ListingStatus.ON_HOLD,0,0,0,0,address(0),0);
        }

        _outstandingPayments[_off.createdByAddress] -= _off.price;
        _outstandingPayments[_commissionReceiver] += ((_off.price * _defaultCommission) / 10000);
        _outstandingPayments[msg.sender] += (_off.price - ((_off.price * _defaultCommission) / 10000));
        _outstandingPayments[ownerRoyaltyAddr] += ownerRoyaltyAmount;
        
        emit OfferAccepted(_off.createdByAddress, msg.sender, _tokenId);
    }
    function withdrawPayment() external returns (bool) {
        uint256 amount = _outstandingPayments[msg.sender];
        if (amount > 0) {
            _outstandingPayments[msg.sender] = 0;

            if (!payable(msg.sender).send(amount)) {
                _outstandingPayments[msg.sender] = amount;
                return false;
            }
            emit PaymentWithdrawn(amount);
        }
        return true;
    }

    function outstandingPayment(address _user) external view returns (uint256) {
        return _outstandingPayments[_user];
    }

    function getAllOffers(address _contractAddress, uint _tokenId) external view returns(Offer[] memory){
        return _offerListing[_contractAddress][_tokenId];
    }

    function getOfferByTimestamp(address _contractAddress, uint _tokenId, address _createdByAddress, uint _startTime) external view returns(Offer memory){
        return _sOfferListing[_contractAddress][_tokenId][_createdByAddress][_startTime];
    }

    //Auction
    function bid(address _contractAddress, uint256 _tokenId, address _itemOwner) external payable {
        require(
            _listings[_contractAddress][_tokenId][_itemOwner].status == ListingStatus.ON_AUCTION,
            "Item not listed for auction."
        );
        require(
            block.timestamp <= _listings[_contractAddress][_tokenId][_itemOwner].endTime &&
                block.timestamp >= _listings[_contractAddress][_tokenId][_itemOwner].startTime,
            "Auction not started/already ended."
        );
        require(
            msg.value > _listings[_contractAddress][_tokenId][_itemOwner].highestBid,
            "There is already a higher bid."
        );

        if (_listings[_contractAddress][_tokenId][_itemOwner].highestBid != 0) {
            _outstandingPayments[
                _listings[_contractAddress][_tokenId][_itemOwner].highestBidder
            ] += _listings[_contractAddress][_tokenId][_itemOwner].highestBid;
        }
        _listings[_contractAddress][_tokenId][_itemOwner].highestBidder = msg.sender;
        _listings[_contractAddress][_tokenId][_itemOwner].highestBid = msg.value;
        emit HighestBidIncreased(_tokenId, _itemOwner, msg.sender, msg.value);
    }
    function auctionEnd(address _contractAddress, uint256 _tokenId, address _itemOwner, bool isIERC2981) external {
        require(
            _listings[_contractAddress][_tokenId][_itemOwner].status == ListingStatus.ON_AUCTION,
            "Auction end: item is not for auction"
        );
        require(
            block.timestamp > _listings[_contractAddress][_tokenId][_itemOwner].endTime,
            "Auction end: auction not yet ended."
        );

        uint256 commision =
            (_listings[_contractAddress][_tokenId][_itemOwner].highestBid * _defaultCommission) / 10000;

        address ownerRoyaltyAddr;
        uint ownerRoyaltyAmount;
        if (_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC721) {
            IERC721(_contractAddress).safeTransferFrom(_itemOwner, msg.sender, _tokenId,'AUCTION');
        } else if(_listings[_contractAddress][_tokenId][_itemOwner].assetType == AssetType.ERC1155) {
            IERC1155(_contractAddress).safeTransferFrom(_itemOwner, msg.sender, _tokenId, _listings[_contractAddress][_tokenId][_itemOwner].numOfCopies, "",'AUCTION');
        }
        if(isIERC2981){
            (ownerRoyaltyAddr,ownerRoyaltyAmount) = IERC2981(_contractAddress).royaltyInfo(_tokenId, _listings[_contractAddress][_tokenId][_itemOwner].highestBid);
        }
        _listings[_contractAddress][_tokenId][_itemOwner] = Listing({
            contractAddress: address(0),
            assetType: AssetType.UNKNOWN,
            status: ListingStatus.ON_HOLD,
            numOfCopies:_listings[_contractAddress][_tokenId][_itemOwner].numOfCopies,
            price: 0,
            startTime: 0,
            endTime: 0,
            highestBidder: _listings[_contractAddress][_tokenId][_itemOwner].highestBidder,
            highestBid: _listings[_contractAddress][_tokenId][_itemOwner].highestBid
        });
        emit AuctionEnded(
            _tokenId,
            _itemOwner,
            _listings[_contractAddress][_tokenId][_itemOwner].highestBidder,
            _listings[_contractAddress][_tokenId][_itemOwner].highestBid
        );

        _outstandingPayments[_commissionReceiver] += commision;
        _outstandingPayments[_itemOwner] += (_listings[_contractAddress][_tokenId][_itemOwner].highestBid - commision);
        _outstandingPayments[ownerRoyaltyAddr] += ownerRoyaltyAmount;
        emit TransferCommission(_commissionReceiver, _tokenId, commision);
        emit TransferRoyalty(ownerRoyaltyAddr, _tokenId, ownerRoyaltyAmount);
    }
    function _checkTypeAndBalance(AssetType _assetType, address _contractAddress, uint _tokenId, uint _numOfCopies) internal view {
        if (_assetType == AssetType.ERC721) {
            require(
                IERC721(_contractAddress).balanceOf(msg.sender) > 0,
                "Marketplace: Insufficient Balance"
            );
            
            require(IERC721(_contractAddress).isApprovedForAll(msg.sender,address(this)),"Marketplace:should call setApproveForAll");
        } else if(_assetType == AssetType.ERC1155) {
            require(
                IERC1155(_contractAddress).balanceOf(msg.sender, _tokenId) >= _numOfCopies,
                "Marketplace: Insufficient Balance"
            );
            require(IERC1155(_contractAddress).isApprovedForAll(msg.sender,address(this)),"Marketplace:should call setApproveForAll");
        }
    }
    function _checkBalanceAndOwnership(AssetType _assetType, address[] memory _offeredTokenAddress,uint[] memory _offeredTokenId,uint _numOfCopies) internal view {
         if (_assetType == AssetType.ERC721) {
            for(uint i = 0; i<_offeredTokenAddress.length; i++){
                require(IERC721(_offeredTokenAddress[i]).balanceOf(msg.sender) > 0,"Marketplace: Insufficient Balance");
                require(IERC721(_offeredTokenAddress[i]).ownerOf(_offeredTokenId[i]) == msg.sender,"Marketplace: not an owner");
            }
         }
         else if(_assetType == AssetType.ERC1155) {
            for(uint i = 0; i<_offeredTokenAddress.length; i++){
                require(IERC1155(_offeredTokenAddress[i]).balanceOf(msg.sender, _offeredTokenId[i]) >= _numOfCopies,"Marketplace: Insufficient Balance");
            }
         } 
    }
    function _checkOfferTypeAndTransfer(Offer memory _off,  uint _tokenId) internal {
        if(_off.assetType == AssetType.ERC721){
            require(IERC721(_off.contractAddress).balanceOf(msg.sender) > 0,"Marketplace: Insufficient Balance");
            IERC721(_off.contractAddress).safeTransferFrom(msg.sender, _off.createdByAddress, _tokenId,"OFFER");
            for(uint i = 0; i<_off.offeredTokenAddress.length; i++){
                IERC721(_off.offeredTokenAddress[i]).safeTransferFrom(_off.createdByAddress, msg.sender,_off.offeredTokenId[i],"OFFER");
            }
        } else if(_off.assetType == AssetType.ERC1155) {
            require(IERC1155(_off.contractAddress).balanceOf(msg.sender, _tokenId) >= _off.numOfCopies,"Marketplace: Insufficient Balance");
            IERC1155(_off.contractAddress).safeTransferFrom(msg.sender, _off.createdByAddress, _tokenId, _off.numOfCopies, "","OFFER");
            // copiesLeft = _listings[_off.contractAddress][_tokenId][msg.sender].numOfCopies - _off.numOfCopies;
            for(uint i = 0; i<_off.offeredTokenAddress.length; i++){
                IERC1155(_off.offeredTokenAddress[i]).safeTransferFrom( _off.createdByAddress,msg.sender, _off.offeredTokenId[i], 1, "","OFFER");
            }
        }
    }
}