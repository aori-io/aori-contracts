// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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

import {SeaportInterface} from "seaport-types/src/interfaces/SeaportInterface.sol";
import {AdvancedOrder, CriteriaResolver, Fulfillment, OrderParameters, OrderComponents} from "seaport-types/src/lib/ConsiderationStructs.sol";

contract OrderProtocol {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public seaport;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct MatchingDetails {
        // Order details specific to Seaport
        AdvancedOrder[] makerOrders;
        AdvancedOrder takerOrder;
        Fulfillment[] fulfillments;
        uint256 blockDeadline;
        uint256 chainId;
    }

    struct Signature {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event TradeOccurred();

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _owner, address _seaport) {
        owner = _owner;
        seaport = _seaport;
    }

    /*//////////////////////////////////////////////////////////////
                               SETTLEMENT
    //////////////////////////////////////////////////////////////*/

    function settleOrders(
        MatchingDetails memory matching,
        Signature memory serverSignature
    ) external {

        // Create matching hash that would have been signed off by the server
        bytes32 matchingHash = keccak256(
            abi.encode(
                matching.makerOrders,
                matching.takerOrder,
                matching.fulfillments,
                matching.blockDeadline,
                matching.chainId
            )
        );

        // Ensure that the server has signed off on these matching details
        require(
            owner ==
                ecrecover(
                    keccak256(
                        abi.encodePacked(
                            "\x19Ethereum Signed Message:\n32",
                            matchingHash
                        )
                    ),
                    serverSignature.v,
                    serverSignature.r,
                    serverSignature.s
                ),
            "Server signature does not correspond to order details"
        );

        // Ensure that block deadline to execute has not passed
        require(
            matching.blockDeadline >= block.number,
            "Order execution deadline has passed"
        );

        // And the chainId is the set chainId for the order such that
        // we can protect against cross-chain signature replay attacks.
        require(
            matching.chainId == block.chainid,
            "Order is not valid for this chain"
        );

        // Aggregate orders into one array
        AdvancedOrder[] memory orders = new AdvancedOrder[](
            matching.makerOrders.length + 1
        );
        for (uint256 i = 0; i < matching.makerOrders.length; i++) {
            orders[i] = matching.makerOrders[i];
        }
        orders[matching.makerOrders.length] = matching.takerOrder;

        // Make matchAdvancedOrders call
        SeaportInterface(seaport).matchAdvancedOrders(
            orders,
            new CriteriaResolver[](0),
            matching.fulfillments,
            msg.sender
        );

        // Emit trade event for (subgraph) indexers
        emit TradeOccurred();
    }

    /*//////////////////////////////////////////////////////////////
                                  MISC
    //////////////////////////////////////////////////////////////*/

    function version() public pure returns (string memory) {
        return "1.0";
    }
}