pragma solidity >=0.8.17;

import {DSTest} from "ds-test/test.sol";
import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {SeaportInterface} from "seaport-types/src/interfaces/SeaportInterface.sol";
import {ConsiderationInterface} from "seaport-types/src/interfaces/ConsiderationInterface.sol";
import {AdvancedOrder, CriteriaResolver, Fulfillment, FulfillmentComponent, OrderParameters, OfferItem, ConsiderationItem, CriteriaResolver, ItemType, OrderComponents} from "seaport-types/src/lib/ConsiderationStructs.sol";
import {OrderType, Side} from "seaport-types/src/lib/ConsiderationEnums.sol";

import {OrderProtocol} from "../src/OrderProtocol.sol";

import {SimpleToken} from "./mocks/SimpleToken.sol";

import {OrderHasher} from "./utils/OrderHasher.sol";

contract OrderProtocolTest is DSTest {
    Vm internal vm = Vm(HEVM_ADDRESS);
    address constant SEAPORT_ADDRESS =
        0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC;
    OrderProtocol internal orderProtocol;

    bytes32 internal _OFFER_ITEM_TYPEHASH;
    bytes32 internal _CONSIDERATION_ITEM_TYPEHASH;
    bytes32 internal _ORDER_TYPEHASH;

    /*//////////////////////////////////////////////////////////////
                                 USERS
    //////////////////////////////////////////////////////////////*/

    uint256 FAKE_ORDER_PROTOCOL_KEY = 69;
    uint256 SERVER_PRIVATE_KEY = 1;
    uint256 FAKE_SERVER_PRIVATE_KEY = 2;
    uint256 MAKER_PRIVATE_KEY = 3;
    uint256 FAKE_MAKER_PRIVATE_KEY = 4;
    uint256 TAKER_PRIVATE_KEY = 5;
    uint256 FAKE_TAKER_PRIVATE_KEY = 6;
    uint256 SEARCHER_PRIVATE_KEY = 7;

    address FAKE_ORDER_PROTOCOL = address(vm.addr(FAKE_ORDER_PROTOCOL_KEY));
    address SERVER_WALLET = address(vm.addr(SERVER_PRIVATE_KEY));
    address FAKE_SERVER_WALLET = address(vm.addr(FAKE_SERVER_PRIVATE_KEY));
    address MAKER_WALLET = address(vm.addr(MAKER_PRIVATE_KEY));
    address FAKE_MAKER_WALLET = address(vm.addr(FAKE_MAKER_PRIVATE_KEY));
    address TAKER_WALLET = address(vm.addr(TAKER_PRIVATE_KEY));
    address FAKE_TAKER_WALLET = address(vm.addr(FAKE_TAKER_PRIVATE_KEY));
    address SEARCHER_WALLET = address(vm.addr(SEARCHER_PRIVATE_KEY));

    /*//////////////////////////////////////////////////////////////
                                 ASSETS
    //////////////////////////////////////////////////////////////*/

    SimpleToken tokenA = new SimpleToken();
    SimpleToken tokenB = new SimpleToken();

    OfferItem[] internal offerItems;
    ConsiderationItem[] internal considerationItems;
    AdvancedOrder[] internal advancedOrders;

    bytes32[] internal criteriaProofs;
    CriteriaResolver[] internal criteriaResolvers;
    FulfillmentComponent[] internal offerFulfillmentComponents;
    FulfillmentComponent[] internal considerationFulfillmentComponents;
    Fulfillment[] internal fulfillments;

    OrderHasher internal orderHasher;

    function setUp() public {
        vm.prank(SERVER_WALLET);
        orderProtocol = new OrderProtocol(SERVER_WALLET, SEAPORT_ADDRESS);

        vm.label(address(orderProtocol), "Order Protocol");
        vm.label(FAKE_ORDER_PROTOCOL, "Fake Order Protocol");
        vm.label(SEAPORT_ADDRESS, "Seaport Deployment");

        vm.label(SERVER_WALLET, "Server Wallet");
        vm.label(FAKE_SERVER_WALLET, "Fake Server Wallet");
        vm.label(MAKER_WALLET, "Maker Wallet");
        vm.label(FAKE_MAKER_WALLET, "Fake Maker Wallet");
        vm.label(TAKER_WALLET, "Taker Wallet");
        vm.label(FAKE_TAKER_WALLET, "Fake Taker Wallet");

        vm.label(address(tokenA), "TokenA");
        vm.label(address(tokenB), "TokenB");

        orderHasher = new OrderHasher();
    }

    function test_failFakeServerSignature() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 fakeServerV, bytes32 fakeServerR, bytes32 fakeServerS) = vm.sign(
            FAKE_SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert(
            "Server signature does not correspond to order details"
        );
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({
                v: fakeServerV,
                r: fakeServerR,
                s: fakeServerS
            })
        );
        vm.stopPrank();
    }

    function test_failChainIdBlockDeadlineExpired() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number - 1,
                69420
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert("Order execution deadline has passed");
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number - 1,
                chainId: 69420
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failChainIdWrongChainId() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                69420
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert("Order is not valid for this chain");
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: 69420
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failTakerOrderSignedByFake() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            FAKE_TAKER_PRIVATE_KEY, // Note: here is the fake private key!
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert(bytes4(0x815e1d64)); // Encoded selector for InvalidSigner()
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failEmptyMakerOrders() public {
        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert(bytes4(0x7fda7279)); // InvalidFulfillmentComponentData()
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failMakerNotApprovedTokens() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        // Note: Commented out for the test
        // IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert("ERC20: insufficient allowance");
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failTakerNotApprovedTokens() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        // IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        vm.expectRevert("ERC20: insufficient allowance");
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failEmptyFulfillment() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        // Note: removed for test

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        // TODO: fix
        // vm.expectRevert(bytes4(0xa5f54208)); // ConsiderationNotMet(uint256,uint256,uint256)
        vm.expectRevert();
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failFulfillmentForNoneExistent() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 1));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        // TODO:
        // vm.expectRevert("bced929d");
        vm.expectRevert();
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_failConsiderationsNotMet() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 0.8 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        // vm.expectRevert("0xa5f54208"); // ConsiderationNotMet(uint256,uint256,uint256)
        vm.expectRevert();
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_successPartialFill() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 0.9 ether,
            denominator: 1 ether,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 0.9 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                0.9 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 1 ether,
            denominator: 1 ether,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();

        assertEq(IERC20(address(tokenA)).balanceOf(MAKER_WALLET), 0.1 ether);
        assertEq(IERC20(address(tokenB)).balanceOf(MAKER_WALLET), 0.9 ether);

        assertEq(IERC20(address(tokenB)).balanceOf(TAKER_WALLET), 0.1 ether);
        assertEq(IERC20(address(tokenA)).balanceOf(TAKER_WALLET), 0.9 ether);
    }

    function test_successSimpleSwap() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_successPartialMultiSwap() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                0.9 ether,
                MAKER_WALLET
            )
        );
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                0.1 ether,
                SERVER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 0.5 ether,
            denominator: 1 ether,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 0.5 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                0.5 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        // Apply maker's offer item to the taker's consideration
        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        // Apply the taker's offer to the maker's considerations
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        Fulfillment memory fulfillment3 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        fulfillment3.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment3.considerationComponents[0] = FulfillmentComponent(0, 1);
        fulfillments.push(fulfillment3);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_successWholeMultiSwap() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                0.9 ether,
                MAKER_WALLET
            )
        );
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                0.1 ether,
                SERVER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        // Apply maker's offer item to the taker's consideration
        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        // Apply the taker's offer to the maker's considerations
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        Fulfillment memory fulfillment3 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        fulfillment3.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment3.considerationComponents[0] = FulfillmentComponent(0, 1);
        fulfillments.push(fulfillment3);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    function test_successDynamicFeeSwap() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 0.9 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                0.9 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        // Taker pays 0.9 ether for maker's consideration + 0.1 ether taker fee
        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                0.9 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        considerationItems.push(_createBaseConsiderationItemERC20(
            address(tokenA),
            0.05 ether,
            SERVER_WALLET
        ));

        considerationItems.push(_createBaseConsiderationItemERC20(
            address(tokenA),
            0.05 ether,
            FAKE_SERVER_WALLET
        ));

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });
        
        // /*//////////////////////////////////////////////////////////////
        //                        DYNAMIC TAKER FEE
        // //////////////////////////////////////////////////////////////*/

        // offerItems.push(_createBaseOfferItemERC20(address(tokenB), 0 ether));
        // considerationItems.push(
        //     _createBaseConsiderationItemERC20(
        //         address(tokenA),
        //         0.1 ether,
        //         SERVER_WALLET
        //     )
        // );
        // OrderParameters memory takerFeeParameters = _createBaseOrderParameters(
        //     TAKER_WALLET,
        //     address(orderProtocol)
        // );
        // OrderComponents memory takerFeeComponents = _getOrderComponents(
        //     takerFeeParameters
        // );

        // bytes memory takerFeeSignature = this._signOrder(
        //     TAKER_PRIVATE_KEY,
        //     orderHasher._getOrderHash(takerFeeComponents)
        // );

        // AdvancedOrder memory takerFee = AdvancedOrder({
        //     parameters: takerFeeParameters,
        //     numerator: 10,
        //     denominator: 10,
        //     signature: takerFeeSignature,
        //     extraData: "0x"
        // });
        // advancedOrders.push(takerFee);

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        // Apply maker's offer item to the taker's consideration
        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        // Apply the taker's offer to the maker's considerations
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        Fulfillment memory fulfillment3 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        fulfillment3.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment3.considerationComponents[0] = FulfillmentComponent(1, 1);
        fulfillments.push(fulfillment3);

        Fulfillment memory fulfillment4 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );

        fulfillment4.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment4.considerationComponents[0] = FulfillmentComponent(1, 2);
        fulfillments.push(fulfillment4);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(SEARCHER_WALLET);
        orderProtocol.settleOrders(
            OrderProtocol.MatchingDetails({
                makerOrders: advancedOrders,
                takerOrder: takerOrder,
                fulfillments: fulfillments,
                blockDeadline: block.number,
                chainId: block.chainid
            }),
            OrderProtocol.Signature({v: serverV, r: serverR, s: serverS})
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        SIGNATURE REPLAY ATTACKS
    //////////////////////////////////////////////////////////////*/

    function test_failSignatureReplayAttackMakerExecute() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        advancedOrders.push(takerOrder);

        vm.expectRevert();
        vm.startPrank(MAKER_WALLET);
        SeaportInterface(SEAPORT_ADDRESS).matchAdvancedOrders(
            advancedOrders,
            new CriteriaResolver[](0),
            fulfillments,
            MAKER_WALLET
        );
        vm.stopPrank();
    }

    function test_failSignatureReplayAttackTakerExecute() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        advancedOrders.push(takerOrder);

        vm.expectRevert();
        vm.startPrank(TAKER_WALLET);
        SeaportInterface(SEAPORT_ADDRESS).matchAdvancedOrders(
            advancedOrders,
            new CriteriaResolver[](0),
            fulfillments,
            MAKER_WALLET
        );
        vm.stopPrank();
    }

    function test_failSignatureReplayAttackTakerExecuteMakerRecipient() public {
        /*//////////////////////////////////////////////////////////////
                                ORDER CREATION
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenA), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenB),
                1 ether,
                MAKER_WALLET
            )
        );

        OrderParameters memory parameters = _createBaseOrderParameters(
            MAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory makerOrderComponents = _getOrderComponents(
            parameters
        );

        bytes memory makerSignature = this._signOrder(
            MAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(makerOrderComponents)
        );

        AdvancedOrder memory order1 = AdvancedOrder({
            parameters: parameters,
            numerator: 10,
            denominator: 10,
            signature: makerSignature,
            extraData: "0x"
        });
        advancedOrders.push(order1);

        /*//////////////////////////////////////////////////////////////
                                  TAKER ORDER
        //////////////////////////////////////////////////////////////*/

        offerItems.push(_createBaseOfferItemERC20(address(tokenB), 1 ether));
        considerationItems.push(
            _createBaseConsiderationItemERC20(
                address(tokenA),
                1 ether,
                TAKER_WALLET
            )
        );

        OrderParameters memory takerParameters = _createBaseOrderParameters(
            TAKER_WALLET,
            address(orderProtocol)
        );
        OrderComponents memory takerOrderComponents = _getOrderComponents(
            takerParameters
        );

        bytes memory takerSignature = this._signOrder(
            TAKER_PRIVATE_KEY,
            orderHasher._getOrderHash(takerOrderComponents)
        );

        AdvancedOrder memory takerOrder = AdvancedOrder({
            parameters: takerParameters,
            numerator: 10,
            denominator: 10,
            signature: takerSignature,
            extraData: "0x"
        });

        /*//////////////////////////////////////////////////////////////
                                FULFILLMENTS
        //////////////////////////////////////////////////////////////*/

        offerFulfillmentComponents.push(FulfillmentComponent(0, 0));
        considerationFulfillmentComponents.push(FulfillmentComponent(1, 0));

        Fulfillment memory fulfillment = Fulfillment(
            offerFulfillmentComponents,
            considerationFulfillmentComponents
        );

        Fulfillment memory fulfillment2 = Fulfillment(
            new FulfillmentComponent[](1),
            new FulfillmentComponent[](1)
        );
        fulfillment2.offerComponents[0] = FulfillmentComponent(1, 0);
        fulfillment2.considerationComponents[0] = FulfillmentComponent(0, 0);

        fulfillments.push(fulfillment);
        fulfillments.push(fulfillment2);

        /*//////////////////////////////////////////////////////////////
                                SERVER SIGNATURE
        //////////////////////////////////////////////////////////////*/

        bytes32 matchingHash = keccak256(
            abi.encode(
                advancedOrders,
                takerOrder,
                fulfillments,
                block.number,
                block.chainid
            )
        );

        (uint8 serverV, bytes32 serverR, bytes32 serverS) = vm.sign(
            SERVER_PRIVATE_KEY,
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    matchingHash
                )
            )
        );

        /*//////////////////////////////////////////////////////////////
                                    SETTLEMENT
        //////////////////////////////////////////////////////////////*/

        vm.startPrank(MAKER_WALLET);
        IERC20(address(tokenA)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenA.mint(1 ether);
        vm.stopPrank();

        vm.startPrank(TAKER_WALLET);
        IERC20(address(tokenB)).approve(SEAPORT_ADDRESS, 2 ** 256 - 1);
        tokenB.mint(1 ether);
        vm.stopPrank();

        advancedOrders.push(takerOrder);

        vm.expectRevert();
        vm.startPrank(TAKER_WALLET);
        SeaportInterface(SEAPORT_ADDRESS).matchAdvancedOrders(
            advancedOrders,
            new CriteriaResolver[](0),
            fulfillments,
            MAKER_WALLET
        );
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _createBaseOfferItemERC20(
        address _tokenAddress,
        uint256 _amount
    ) internal pure returns (OfferItem memory) {
        return
            OfferItem({
                itemType: ItemType.ERC20,
                token: _tokenAddress,
                identifierOrCriteria: 0,
                startAmount: _amount,
                endAmount: _amount
            });
    }

    function _createBaseConsiderationItemERC20(
        address _tokenAddress,
        uint256 _amount,
        address _recipient
    ) internal pure returns (ConsiderationItem memory) {
        return
            ConsiderationItem({
                itemType: ItemType.ERC20,
                token: _tokenAddress,
                identifierOrCriteria: 0,
                startAmount: _amount,
                endAmount: _amount,
                recipient: payable(_recipient)
            });
    }

    function _createBaseOrderParameters(
        address _offerer,
        address _zone
    ) internal returns (OrderParameters memory) {
        OrderParameters memory parameters = OrderParameters({
            offerer: _offerer,
            zone: _zone,
            offer: offerItems,
            consideration: considerationItems,
            orderType: OrderType.PARTIAL_RESTRICTED,
            startTime: 0,
            endTime: block.timestamp * 2,
            zoneHash: bytes32(0),
            salt: 0,
            conduitKey: bytes32(0),
            totalOriginalConsiderationItems: considerationItems.length
        });

        while (offerItems.length > 0) {
            offerItems.pop();
        }

        while (considerationItems.length > 0) {
            considerationItems.pop();
        }

        return parameters;
    }

    /**
     * @dev return OrderComponents for a given OrderParameters and offerer
     *      counter
     */
    function _getOrderComponents(
        OrderParameters memory parameters
    ) internal view returns (OrderComponents memory) {
        return
            OrderComponents(
                parameters.offerer,
                parameters.zone,
                parameters.offer,
                parameters.consideration,
                parameters.orderType,
                parameters.startTime,
                parameters.endTime,
                parameters.zoneHash,
                parameters.salt,
                parameters.conduitKey,
                SeaportInterface(SEAPORT_ADDRESS).getCounter(parameters.offerer) // counter
            );
    }

    function _signOrder(
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) external view returns (bytes memory) {
        (bytes32 r, bytes32 s, uint8 v) = getSignatureComponents(
            ConsiderationInterface(SEAPORT_ADDRESS), // seaport address
            _pkOfSigner,
            _orderHash
        );
        return abi.encodePacked(r, s, v);
    }

    function getSignatureComponents(
        ConsiderationInterface _consideration,
        uint256 _pkOfSigner,
        bytes32 _orderHash
    ) internal view returns (bytes32, bytes32, uint8) {
        (, bytes32 domainSeparator, ) = _consideration.information();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            _pkOfSigner,
            keccak256(
                abi.encodePacked(bytes2(0x1901), domainSeparator, _orderHash)
            )
        );
        return (r, s, v);
    }
}
