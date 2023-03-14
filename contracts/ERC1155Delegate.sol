// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IDelegate.sol";
import "./interfaces/IERC1155.sol";

contract ERC1155Delegate is AccessControl, IERC1155Receiver,IDelegate{
    bytes32 public constant DELEGATION_CALLER = keccak256('DELEGATION_CALLER');

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function onERC1155Received(
        address, // operator,
        address, // from,
        uint256, // id,
        uint256, // value,
        bytes calldata // data
    ) external override pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address, // operator,
        address, // from,
        uint256[] calldata, // ids,
        uint256[] calldata, // values,
        bytes calldata // data
    ) external override pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function delegateType() external pure returns (uint256) {
        return 2;
    }

    
    function executeSell(
        address contractAddress,
        address seller,
        address buyer,
        uint256 tokenId,
        uint amount,
        string memory _type
    ) external onlyRole(DELEGATION_CALLER) returns(bool){
        _assertAmount(amount);
        IERC1155(contractAddress).safeTransferFrom(seller, buyer, tokenId,amount,"",_type);
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
        _assertAmount(amount);
        IERC1155(contractAddress).safeTransferFrom(seller, buyer, tokenId,amount,"",_type);
        return true;
    }

    function _assertAmount(uint amount) internal pure {
        require(amount > 0, 'Delegate: amount > 0');
    }
}