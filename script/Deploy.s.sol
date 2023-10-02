// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/OrderProtocol.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        OrderProtocol orderProtocol = new OrderProtocol(
            0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC
            );
        vm.stopBroadcast();
    }
}
