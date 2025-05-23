// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import "../src/PredictionMarketV2.sol";

contract DeployPredictionMarket is Script {
    function run() external {
        vm.startBroadcast();

        PredictionMarketV2 market = new PredictionMarketV2();
        console2.log("Deployed to:", address(market));

        vm.stopBroadcast();
    }
}

/*
 source .env
forge script script/Deploy.s.sol:DeployPredictionMarket \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

*/