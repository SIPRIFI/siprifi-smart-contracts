// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BlockchainCDS {

    /*//////////////////////////////////////////////////////////////
                                TYPES
    //////////////////////////////////////////////////////////////*/

    enum CDSStatus {
        Open,
        Active,
        Triggered,
        Expired
    }

    struct CDS {
        address seller;              // Protection seller
        address buyer;               // Protection buyer
        string eventDescription;     // Human-readable event
        uint256 notional;            // Amount insured
        uint256 collateral;          // Locked by seller (== notional)
        uint256 premium;             // Periodic premium
        uint256 premiumInterval;     // Time between premium payments
        uint256 lastPremiumPaid;     // Timestamp
        uint256 maturity;            // Expiration timestamp
        CDSStatus status;            // Current state
        bool eventOccurred;          // Event resolution
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE
    //////////////////////////////////////////////////////////////*/

    address public organization;
    uint256 public cdsCount;
    mapping(uint256 => CDS) public cdsContracts;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event CDSCreated(uint256 indexed cdsId, address indexed seller, uint256 notional);
    event CDSBought(uint256 indexed cdsId, address indexed buyer);
    event PremiumPaid(uint256 indexed cdsId, uint256 amount);
    event CDSTriggered(uint256 indexed cdsId);
    event CDSExpired(uint256 indexed cdsId);
    event OrganizationUpdated(address oldOrg, address newOrg);

    /*//////////////////////////////////////////////////////////////
                             MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOrganization() {
        require(msg.sender == organization, "Not authorized");
        _;
    }

    modifier onlyBuyer(uint256 id) {
        require(msg.sender == cdsContracts[id].buyer, "Not buyer");
        _;
    }

    modifier active(uint256 id) {
        require(cdsContracts[id].status == CDSStatus.Active, "Not active");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _organization) {
        require(_organization != address(0), "Invalid organization");
        organization = _organization;
    }

    /*//////////////////////////////////////////////////////////////
                      ORGANIZATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function setOrganization(address newOrganization) external onlyOrganization {
        require(newOrganization != address(0), "Invalid organization");
        address old = organization;
        organization = newOrganization;
        emit OrganizationUpdated(old, newOrganization);
    }

    /*//////////////////////////////////////////////////////////////
                       CDS CORE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // 1️⃣ Create CDS (seller deposits full collateral)
    function createCDS(
        string calldata eventDescription,
        uint256 notional,
        uint256 premium,
        uint256 premiumInterval,
        uint256 maturity
    ) external payable returns (uint256) {
        require(msg.value == notional, "Collateral must equal notional");
        require(maturity > block.timestamp, "Invalid maturity");
        require(premiumInterval > 0, "Invalid interval");

        cdsCount++;

        cdsContracts[cdsCount] = CDS({
            seller: msg.sender,
            buyer: address(0),
            eventDescription: eventDescription,
            notional: notional,
            collateral: msg.value,
            premium: premium,
            premiumInterval: premiumInterval,
            lastPremiumPaid: 0,
            maturity: maturity,
            status: CDSStatus.Open,
            eventOccurred: false
        });

        emit CDSCreated(cdsCount, msg.sender, notional);
        return cdsCount;
    }

    // 2️⃣ Buy protection
    function buyCDS(uint256 id) external {
        CDS storage c = cdsContracts[id];
        require(c.status == CDSStatus.Open, "Not open");
        require(block.timestamp < c.maturity, "Expired");

        c.buyer = msg.sender;
        c.status = CDSStatus.Active;
        c.lastPremiumPaid = block.timestamp;

        emit CDSBought(id, msg.sender);
    }

    // 3️⃣ Pay premium
    function payPremium(uint256 id) external payable onlyBuyer(id) active(id) {
        CDS storage c = cdsContracts[id];
        require(msg.value == c.premium, "Incorrect premium");
        require(block.timestamp <= c.maturity, "Expired");
        require(
            block.timestamp >= c.lastPremiumPaid + c.premiumInterval,
            "Too early"
        );

        c.lastPremiumPaid = block.timestamp;
        payable(c.seller).transfer(msg.value);

        emit PremiumPaid(id, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                     EVENT RESOLUTION (CENTRALIZED)
    //////////////////////////////////////////////////////////////*/

    // 4️⃣ Organization resolves event
    function resolveEvent(
        uint256 id,
        bool occurred
    ) external onlyOrganization active(id) {
        CDS storage c = cdsContracts[id];
        require(block.timestamp <= c.maturity, "Already matured");

        if (occurred) {
            c.eventOccurred = true;
            c.status = CDSStatus.Triggered;
            payable(c.buyer).transfer(c.notional);
            emit CDSTriggered(id);
        } else {
            c.status = CDSStatus.Expired;
            payable(c.seller).transfer(c.collateral);
            emit CDSExpired(id);
        }
    }

    /*//////////////////////////////////////////////////////////////
                       EXPIRATION FALLBACK
    //////////////////////////////////////////////////////////////*/

    // 5️⃣ Anyone can expire after maturity if no event
    function expireCDS(uint256 id) external active(id) {
        CDS storage c = cdsContracts[id];
        require(block.timestamp > c.maturity, "Not matured");

        c.status = CDSStatus.Expired;
        payable(c.seller).transfer(c.collateral);

        emit CDSExpired(id);
    }
}
