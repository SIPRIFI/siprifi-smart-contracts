// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./MarketToken.sol";

contract PredictionMarketV2 {
    uint256 public marketCount;

    enum MarketStatus { InProgress, Occurred }

    event MarketCreated(uint256 indexed marketId, string question, uint256 deadline, address yesToken, address noToken);
    event MarketResolved(uint256 indexed marketId, uint8 outcome);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, uint256 amount);
    event OwnershipTransferred(uint256 indexed marketId, address indexed oldOwner, address indexed newOwner);
    event MarketStatusUpdated(uint256 indexed marketId, MarketStatus status);
    event RewardClaimed(uint256 indexed marketId, address indexed user, uint256 amount);

    struct Market {
        address owner;
        string question;
        uint256 deadline;
        MarketStatus status;
        bool resolved;
        uint8 outcome; // 0 = No, 1 = Yes
        address yesToken;
        address noToken;
        bool exists;
    }

    mapping(uint256 => Market) public markets;

    modifier onlyOwner(uint256 marketId) {
        require(msg.sender == markets[marketId].owner, "Not market owner");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(markets[marketId].exists, "Market doesn't exist");
        _;
    }

    function createMarket(string memory question, uint256 deadline) external returns (uint256) {
        require(deadline > block.timestamp, "Invalid deadline");

        uint256 newMarketId = ++marketCount;

        string memory yesName = string(abi.encodePacked("YES-", uint2str(newMarketId)));
        string memory noName = string(abi.encodePacked("NO-", uint2str(newMarketId)));

        MarketToken yesToken = new MarketToken(yesName, yesName, address(this));
        MarketToken noToken = new MarketToken(noName, noName, address(this));

        markets[newMarketId] = Market({
            owner: msg.sender,
            question: question,
            deadline: deadline,
            status: MarketStatus.InProgress,
            resolved: false,
            outcome: 2, // undefined
            yesToken: address(yesToken),
            noToken: address(noToken),
            exists: true
        });

        emit MarketCreated(newMarketId, question, deadline, address(yesToken), address(noToken));
        return newMarketId;
    }

    function buyYesShares(uint256 marketId) external payable marketExists(marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp < m.deadline, "Market closed");
        require(msg.value > 0, "Send ETH");

        MarketToken yes = MarketToken(m.yesToken);
        MarketToken no = MarketToken(m.noToken);

        // Mint YES shares to buyer
        yes.mint(msg.sender, msg.value);

        // Mint NO shares to market owner
        no.mint(m.owner, msg.value);

        emit SharesPurchased(marketId, msg.sender, msg.value);
    }

    function transferMarketOwnership(uint256 marketId, address newOwner) external onlyOwner(marketId) {
        address oldOwner = markets[marketId].owner;
        markets[marketId].owner = newOwner;
        emit OwnershipTransferred(marketId, oldOwner, newOwner);
    }

    function updateMarketStatus(uint256 marketId, MarketStatus status) external onlyOwner(marketId) {
        require(block.timestamp < markets[marketId].deadline, "Deadline passed");
        markets[marketId].status = status;
        emit MarketStatusUpdated(marketId, status);
    }

    function resolveMarket(uint256 marketId, uint8 outcome) external onlyOwner(marketId) marketExists(marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp >= m.deadline, "Too early");
        require(!m.resolved, "Already resolved");
        require(outcome == 0 || outcome == 1, "Invalid outcome");

        m.resolved = true;
        m.outcome = outcome;

        emit MarketResolved(marketId, outcome);
    }

    function claimReward(uint256 marketId) external marketExists(marketId) {
        Market storage m = markets[marketId];
        require(m.resolved, "Market not resolved");

        MarketToken token = MarketToken(m.outcome == 1 ? m.yesToken : m.noToken);
        uint256 balance = token.balanceOf(msg.sender);
        require(balance > 0, "No tokens to redeem");

        uint256 totalSupply = token.totalSupply();
        uint256 payout = (address(this).balance * balance) / totalSupply;

        token.burn(msg.sender, balance);
        payable(msg.sender).transfer(payout);

        emit RewardClaimed(marketId, msg.sender, payout);
    }

    // Utility: uint to string
    function uint2str(uint256 _i) internal pure returns (string memory str) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 length;
        while (j != 0) { length++; j /= 10; }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k-1;
            uint8 temp = uint8(48 + _i % 10);
            bstr[k] = bytes1(temp);
            _i /= 10;
        }
        str = string(bstr);
    }

    receive() external payable {}
}
