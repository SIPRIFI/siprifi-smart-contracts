// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/PredictionMarketV2.sol";
import "../src/MarketToken.sol";

contract PredictionMarketV2Test is Test {
    PredictionMarketV2 public market;
    address public owner = address(1);
    address public buyer = address(2);
    uint256 public marketId;

    function setUp() public {
        vm.deal(owner, 100 ether);
        vm.deal(buyer, 100 ether);
        vm.prank(owner);
        market = new PredictionMarketV2();

        vm.prank(owner);
        marketId = market.createMarket("Will ETH > $5k?", block.timestamp + 1 days);
    }

    function testCreateMarket() public {
        (
            address mOwner,
            string memory question,
            uint256 deadline,
            PredictionMarketV2.MarketStatus status,
            bool resolved,
            uint8 outcome,
            address yesToken,
            address noToken,
            bool exists
        ) = market.markets(marketId);

        assertEq(mOwner, owner);
        assertEq(question, "Will ETH > $5k?");
        assertTrue(deadline > block.timestamp);
        assertEq(uint256(status), uint256(PredictionMarketV2.MarketStatus.InProgress));
        assertFalse(resolved);
        assertTrue(exists);
        assertTrue(yesToken != address(0));
        assertTrue(noToken != address(0));
    }

    function testBuyYesSharesAndMintNoShares() public {
        (
            , , , , , , 
            address yesTokenAddr, 
            address noTokenAddr, 
            
        ) = market.markets(marketId);
        MarketToken yesToken = MarketToken(yesTokenAddr);
        MarketToken noToken = MarketToken(noTokenAddr);

        vm.prank(buyer);
        market.buyYesShares{value: 1 ether}(marketId);

        assertEq(yesToken.balanceOf(buyer), 1 ether);
        assertEq(noToken.balanceOf(owner), 1 ether);
    }

    function testTransferOwnership() public {
        address newOwner = address(3);
        vm.prank(owner);
        market.transferMarketOwnership(marketId, newOwner);

        (address updatedOwner,,,,,,, ,) = market.markets(marketId);
        assertEq(updatedOwner, newOwner);
    }

    function testUpdateMarketStatus() public {
        vm.prank(owner);
        market.updateMarketStatus(marketId, PredictionMarketV2.MarketStatus.Occurred);

        (,,, PredictionMarketV2.MarketStatus status,,,, ,) = market.markets(marketId);
        assertEq(uint256(status), uint256(PredictionMarketV2.MarketStatus.Occurred));
    }

    function testResolveAndClaimReward() public {
        (
            , , , , , , 
            address yesTokenAddr, 
            , 
            
        ) = market.markets(marketId);
        MarketToken yesToken = MarketToken(yesTokenAddr);

        vm.prank(buyer);
        market.buyYesShares{value: 1 ether}(marketId);

        vm.warp(block.timestamp + 2 days);

        vm.prank(owner);
        market.resolveMarket(marketId, 1); // YES outcome

        uint256 before = buyer.balance;
        vm.startPrank(buyer);
        yesToken.approve(address(market), type(uint256).max);
        market.claimReward(marketId);
        vm.stopPrank();
        uint256 afterBalance = buyer.balance;

        assertGt(afterBalance, before);
    }
}
