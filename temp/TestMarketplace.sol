// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma abicoder v2;

import './interfaces/IDelegate.sol';
import "./AlvinMarketplaceV2.sol";
import {Order, Status,Side,AssetType,Settle,Input} from "./lib/OrderStruct.sol";

contract TestMarketplace is  AlvinMarketplaceV2{ 
    
    //internal functions
  

    function verifyInputSignature(Input memory input) public view virtual{
        _verifyInputSignature(input);
        
    }
    function verifyOrderSignature(Order memory order) public view virtual{
        _verifyOrderSignature(order);
    }

}