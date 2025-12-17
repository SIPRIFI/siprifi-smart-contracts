// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/PredictionMarket.sol";

contract PredictionMarketTest is Test {
    PredictionMarket pm;
    address creator;
    address stranger;

    function setUp() public {
        creator = vm.addr(1);
        stranger = vm.addr(2);
        pm = new PredictionMarket();
    }

    function testCreatorCanCreateAndResolveMarket() public {
        vm.startPrank(creator);
        uint256 deadline = block.timestamp + 1 days;
        uint256 marketId = pm.createMarket("Will ETH reach $10k?", deadline);

        vm.deal(creator, 1 ether);
        pm.buyShares{value: 1 ether}(marketId, 1);

        vm.warp(deadline + 1);
        pm.resolveMarket(marketId, 1);

        uint256 before = creator.balance;
        pm.claimWinnings(marketId);
        uint256 after1 = creator.balance;

        assertGt(after1, before);
        vm.stopPrank();
    }

    function testStrangerCannotResolveMarket() public {
        vm.prank(creator);
        uint256 deadline = block.timestamp + 1 days;
        uint256 marketId = pm.createMarket("Will BTC drop below $10k?", deadline);

        vm.deal(creator, 1 ether);
        vm.prank(creator);
        pm.buyShares{value: 1 ether}(marketId, 0);

        vm.warp(deadline + 1);

        vm.prank(stranger);
        vm.expectRevert("Not creator");
        pm.resolveMarket(marketId, 0);
    }
}
