// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/PredictionMarket.sol";

contract DeployPredictionMarket is Script {
    function run() external {
        vm.startBroadcast();
        new PredictionMarket();
        vm.stopBroadcast();
    }
}
