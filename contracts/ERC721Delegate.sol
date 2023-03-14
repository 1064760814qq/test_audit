// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import "./interfaces/IERC721.sol";
import "./interfaces/IDelegate.sol";

contract ERC721Delegate is AccessControl, IERC721Receiver,IDelegate{

    bytes32 public constant DELEGATION_CALLER = keccak256('DELEGATION_CALLER');

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external override pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
    function delegateType() external pure returns (uint256){
        return 1; //1 for ERC721
    }
    function executeSell(
        address contractAddress,
        address seller,
        address buyer,
        uint256 tokenId,
        uint amount,
        string memory _type
    ) external onlyRole(DELEGATION_CALLER) returns(bool){

        IERC721(contractAddress).safeTransferFrom(seller, buyer, tokenId,_type);
        return true;
    }

    function executeBuy(
        address contractAddress,
        address seller,
        address buyer,
        uint256 tokenId,
        uint amount,
        string memory _type
    ) external onlyRole(DELEGATION_CALLER) returns(bool){

        IERC721(contractAddress).safeTransferFrom(seller, buyer, tokenId,_type);
        return true;
    }
    //transfer multiple 721s to single address
    function transferBatch(address[] memory contractAddress, uint256[] memory tokenId, address to, string memory _type) public {
        require(contractAddress.length == tokenId.length, 'ERC721Delegate:length doesnot match');
        for (uint256 i = 0; i < contractAddress.length; i++) {
            IERC721(contractAddress[i]).safeTransferFrom(msg.sender, to,tokenId[i],_type);
        }
    }

    function getSender() public view returns(address){return msg.sender;}
}
