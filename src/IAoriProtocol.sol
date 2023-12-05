// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

//                          
//          /@#(@@@@@              
//         @@      @@@             
//          @@                      
//          .@@@#                  
//          ##@@@@@@,              
//        @@@      /@@@&            
//      .@@@  @   @  @@@@           
//      @@@@  @@@@@  @@@@           
//      @@@@  @   @  @@@/           
//       @@@@       @@@             
//         (@@@@#@@@      
//      THE AORI PROTOCOL  

import {AoriProtocol} from "./AoriProtocol.sol";

interface IAoriProtocol {

    function settleOrders(
        AoriProtocol.MatchingDetails memory matching,
        AoriProtocol.Signature memory serverSignature
    ) external;

    function version() external returns (string memory);
}