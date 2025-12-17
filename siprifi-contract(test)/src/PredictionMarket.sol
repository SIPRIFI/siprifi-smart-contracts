// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract PredictionMarket {
    uint256 public marketCount;

    event MarketCreated(uint256 indexed marketId, string question, uint256 deadline);
    event MarketResolved(uint256 indexed marketId, uint8 outcome);
    event SharesPurchased(uint256 indexed marketId, address indexed buyer, uint8 outcome, uint256 amount);

    struct Market {
        address creator;
        string question;
        uint256 deadline;
        bool resolved;
        uint8 outcome; // 0 = No, 1 = Yes
        mapping(uint8 => uint256) totalShares;
        mapping(address => mapping(uint8 => uint256)) userShares;
        bool exists;
    }

    mapping(uint256 => Market) public markets;

    modifier onlyCreator(uint256 marketId) {
        require(msg.sender == markets[marketId].creator, "Not creator");
        _;
    }

    modifier marketExists(uint256 marketId) {
        require(markets[marketId].exists, "Market doesn't exist");
        _;
    }

    function createMarket(string memory question, uint256 deadline) public returns (uint256) {
        require(deadline > block.timestamp, "Invalid deadline");

        uint256 newMarketId = ++marketCount;
        Market storage m = markets[newMarketId];
        m.creator = msg.sender;
        m.question = question;
        m.deadline = deadline;
        m.exists = true;

        emit MarketCreated(newMarketId, question, deadline);
        return newMarketId;
    }

    function buyShares(uint256 marketId, uint8 outcome) public payable marketExists(marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp < m.deadline, "Market closed");
        require(outcome == 0 || outcome == 1, "Invalid outcome");
        require(msg.value > 0, "Must send ETH");

        m.totalShares[outcome] += msg.value;
        m.userShares[msg.sender][outcome] += msg.value;

        emit SharesPurchased(marketId, msg.sender, outcome, msg.value);
    }

    function resolveMarket(uint256 marketId, uint8 correctOutcome) public marketExists(marketId) onlyCreator(marketId) {
        Market storage m = markets[marketId];
        require(block.timestamp >= m.deadline, "Too early");
        require(!m.resolved, "Already resolved");
        require(correctOutcome == 0 || correctOutcome == 1, "Invalid outcome");

        m.resolved = true;
        m.outcome = correctOutcome;

        emit MarketResolved(marketId, correctOutcome);
    }

    function claimWinnings(uint256 marketId) public marketExists(marketId) {
        Market storage m = markets[marketId];
        require(m.resolved, "Not resolved");

        uint256 userShare = m.userShares[msg.sender][m.outcome];
        require(userShare > 0, "Nothing to claim");

        uint256 payout = (userShare * address(this).balance) / m.totalShares[m.outcome];
        m.userShares[msg.sender][m.outcome] = 0;
        payable(msg.sender).transfer(payout);
    }

    function getMarket(uint256 marketId) public view returns (
        address creator,
        string memory question,
        uint256 deadline,
        bool resolved,
        uint8 outcome,
        uint256 yesShares,
        uint256 noShares
    ) {
        Market storage m = markets[marketId];
        return (
            m.creator,
            m.question,
            m.deadline,
            m.resolved,
            m.outcome,
            m.totalShares[1],
            m.totalShares[0]
        );
    }
}
