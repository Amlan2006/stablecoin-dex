// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

/**
 * @title MockPriceFeed
 * @dev Enhanced mock implementation of Chainlink price feed for comprehensive testing
 * Supports price manipulation, staleness simulation, and edge case testing
 */
contract MockPriceFeed is AggregatorV3Interface {
    int256 private _price;
    uint8 private _decimals;
    uint256 private _version;
    string private _description;
    uint80 private _roundId;
    uint256 private _updatedAt;
    bool private _shouldRevert;
    bool private _isStale;
    uint256 private _stalePeriod;

    event PriceUpdated(int256 oldPrice, int256 newPrice, uint80 roundId);
    event StalenessToggled(bool isStale);

    constructor(int256 initialPrice, uint8 decimalsValue) {
        _price = initialPrice;
        _decimals = decimalsValue;
        _version = 1;
        _description = "Mock Price Feed";
        _roundId = 1;
        _updatedAt = block.timestamp;
        _shouldRevert = false;
        _isStale = false;
        _stalePeriod = 3600; // 1 hour default staleness period
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external view override returns (string memory) {
        return _description;
    }

    function version() external view override returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 requestedRoundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_shouldRevert) revert("Mock price feed reverted");
        return (requestedRoundId, _price, _updatedAt, _updatedAt, requestedRoundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_shouldRevert) revert("Mock price feed reverted");
        
        uint256 currentUpdatedAt = _updatedAt;
        if (_isStale) {
            currentUpdatedAt = block.timestamp - _stalePeriod - 1;
        }
        
        return (_roundId, _price, currentUpdatedAt, currentUpdatedAt, _roundId);
    }

    // Test helper functions
    function updatePrice(int256 newPrice) external {
        int256 oldPrice = _price;
        _price = newPrice;
        _roundId++;
        _updatedAt = block.timestamp;
        emit PriceUpdated(oldPrice, newPrice, _roundId);
    }

    function updatePriceWithTimestamp(int256 newPrice, uint256 timestamp) external {
        int256 oldPrice = _price;
        _price = newPrice;
        _roundId++;
        _updatedAt = timestamp;
        emit PriceUpdated(oldPrice, newPrice, _roundId);
    }

    function getPrice() external view returns (int256) {
        return _price;
    }

    function setShouldRevert(bool shouldRevert) external {
        _shouldRevert = shouldRevert;
    }

    function setStalePrice(bool staleness) external {
        _isStale = staleness;
        emit StalenessToggled(staleness);
    }

    function setStalePeriod(uint256 stalePeriod) external {
        _stalePeriod = stalePeriod;
    }

    function getCurrentRoundId() external view returns (uint80) {
        return _roundId;
    }

    function getUpdatedAt() external view returns (uint256) {
        return _updatedAt;
    }

    function isStale() external view returns (bool) {
        return block.timestamp - _updatedAt > _stalePeriod;
    }

    // Simulate price volatility for stress testing
    function simulateVolatility(int256 basePrice, uint256 volatilityPercent, uint256 steps) external {
        for (uint256 i = 0; i < steps; i++) {
            int256 variation = int256((uint256(keccak256(abi.encode(block.timestamp, i))) % (volatilityPercent * 2)) - volatilityPercent);
            int256 newPrice = basePrice + (basePrice * variation / 100);
            this.updatePrice(newPrice > 0 ? newPrice : int256(1));
        }
    }
}

/**
 * @title TestSetup
 * @dev Enhanced base test setup contract with comprehensive mock contracts, utilities, and testing helpers
 * Provides a complete testing environment for the stablecoin-dex system
 */
contract TestSetup is Test {
    // Mock tokens
    ERC20Mock public wethMock;
    ERC20Mock public wbtcMock;
    
    // Mock price feeds
    MockPriceFeed public ethPriceFeed;
    MockPriceFeed public btcPriceFeed;
    
    // Test users
    address public user1;
    address public user2;
    address public user3;
    address public liquidator;
    address public owner;
    address public attacker;
    address public treasury;
    
    // Constants for testing
    uint256 public constant INITIAL_ETH_PRICE = 2000e8; // $2000 with 8 decimals
    uint256 public constant INITIAL_BTC_PRICE = 50000e8; // $50000 with 8 decimals
    uint256 public constant INITIAL_TOKEN_SUPPLY = 1000000e18;
    uint256 public constant HEALTH_FACTOR_THRESHOLD = 150e16; // 1.5 with 18 decimals
    
    // Test scenario constants
    uint256 public constant SMALL_AMOUNT = 1e18;
    uint256 public constant MEDIUM_AMOUNT = 10e18;
    uint256 public constant LARGE_AMOUNT = 100e18;
    uint256 public constant HUGE_AMOUNT = 1000e18;
    
    // Price constants for scenarios
    uint256 public constant HIGH_ETH_PRICE = 3000e8;
    uint256 public constant LOW_ETH_PRICE = 1000e8;
    uint256 public constant HIGH_BTC_PRICE = 70000e8;
    uint256 public constant LOW_BTC_PRICE = 30000e8;
    
    // Liquidation and risk constants
    uint256 public constant LIQUIDATION_THRESHOLD = 110e16; // 1.1 with 18 decimals
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5% bonus
    uint256 public constant MAX_LIQUIDATION_RATIO = 50e16; // 50% max liquidation
    
    // Events for testing
    event TestScenarioStarted(string scenario);
    event TestScenarioCompleted(string scenario);
    event PositionCreated(address indexed user, uint256 collateral, uint256 debt);
    event LiquidationExecuted(address indexed liquidator, address indexed user, uint256 debtCovered);
    
    function setUp() public virtual {
        // Setup test addresses
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        liquidator = makeAddr("liquidator");
        owner = makeAddr("owner");
        attacker = makeAddr("attacker");
        treasury = makeAddr("treasury");
        
        // Deploy mock tokens with proper names and symbols
        wethMock = new ERC20Mock();
        wbtcMock = new ERC20Mock();
        
        // Deploy mock price feeds with initial prices
        ethPriceFeed = new MockPriceFeed(int256(INITIAL_ETH_PRICE), 8);
        btcPriceFeed = new MockPriceFeed(int256(INITIAL_BTC_PRICE), 8);
        
        // Setup initial state
        _mintTokensToUsers();
        _setupLabels();
        _logSetupInfo();
    }
    
    function _mintTokensToUsers() internal {
        // Mint WETH to all test users
        wethMock.mint(user1, INITIAL_TOKEN_SUPPLY);
        wethMock.mint(user2, INITIAL_TOKEN_SUPPLY);
        wethMock.mint(user3, INITIAL_TOKEN_SUPPLY);
        wethMock.mint(liquidator, INITIAL_TOKEN_SUPPLY);
        wethMock.mint(owner, INITIAL_TOKEN_SUPPLY);
        wethMock.mint(attacker, INITIAL_TOKEN_SUPPLY / 10); // Smaller amount for attacker
        
        // Mint WBTC to all test users
        wbtcMock.mint(user1, INITIAL_TOKEN_SUPPLY);
        wbtcMock.mint(user2, INITIAL_TOKEN_SUPPLY);
        wbtcMock.mint(user3, INITIAL_TOKEN_SUPPLY);
        wbtcMock.mint(liquidator, INITIAL_TOKEN_SUPPLY);
        wbtcMock.mint(owner, INITIAL_TOKEN_SUPPLY);
        wbtcMock.mint(attacker, INITIAL_TOKEN_SUPPLY / 10); // Smaller amount for attacker
    }
    
    function _setupLabels() internal {
        // Label addresses for better trace output
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(user3, "User3");
        vm.label(liquidator, "Liquidator");
        vm.label(owner, "Owner");
        vm.label(attacker, "Attacker");
        vm.label(treasury, "Treasury");
        vm.label(address(wethMock), "WETH");
        vm.label(address(wbtcMock), "WBTC");
        vm.label(address(ethPriceFeed), "ETH_PRICE_FEED");
        vm.label(address(btcPriceFeed), "BTC_PRICE_FEED");
    }
    
    function _logSetupInfo() internal {
        console2.log("=== Test Setup Completed ===");
        console2.log("Initial ETH Price:", INITIAL_ETH_PRICE);
        console2.log("Initial BTC Price:", INITIAL_BTC_PRICE);
        console2.log("Initial Token Supply:", INITIAL_TOKEN_SUPPLY);
        console2.log("Health Factor Threshold:", HEALTH_FACTOR_THRESHOLD);
    }
    
    // ==================== Calculation Helpers ====================
    
    function calculateCollateralValue(uint256 collateralAmount, uint256 price) public pure returns (uint256) {
        return (collateralAmount * price) / 1e8;
    }
    
    function calculateHealthFactor(uint256 collateralValue, uint256 debt) public pure returns (uint256) {
        if (debt == 0) {
            return type(uint256).max;
        }
        return (collateralValue * 1e18) / debt;
    }
    
    function isHealthFactorOk(uint256 healthFactor) public pure returns (bool) {
        return healthFactor >= HEALTH_FACTOR_THRESHOLD;
    }
    
    function isUndercollateralized(uint256 healthFactor) public pure returns (bool) {
        return healthFactor < HEALTH_FACTOR_THRESHOLD;
    }
    
    function calculateMaxMintable(uint256 collateralAmount, uint256 price) public pure returns (uint256) {
        uint256 collateralValue = calculateCollateralValue(collateralAmount, price);
        return (collateralValue * 1e18) / HEALTH_FACTOR_THRESHOLD;
    }
    
    function calculateRequiredCollateral(uint256 mintAmount, uint256 price) public pure returns (uint256) {
        uint256 requiredValue = (mintAmount * HEALTH_FACTOR_THRESHOLD) / 1e18;
        return (requiredValue * 1e8) / price;
    }
    
    function calculateLiquidationAmount(uint256 debt, uint256 maxLiquidationRatio) public pure returns (uint256) {
        return (debt * maxLiquidationRatio) / 1e18;
    }
    
    function calculateExchangeRate(uint256 priceA, uint256 priceB) public pure returns (uint256) {
        return (priceA * 1e18) / priceB;
    }
    
    // ==================== Time and Block Helpers ====================
    
    function advanceTime(uint256 timeInSeconds) public {
        vm.warp(block.timestamp + timeInSeconds);
    }
    
    function advanceBlocks(uint256 numberOfBlocks) public {
        vm.roll(block.number + numberOfBlocks);
    }
    
    function advanceTimeAndBlocks(uint256 timeInSeconds, uint256 numberOfBlocks) public {
        vm.warp(block.timestamp + timeInSeconds);
        vm.roll(block.number + numberOfBlocks);
    }
    
    // ==================== Price Manipulation Helpers ====================
    
    function setEthPrice(uint256 newPrice) public {
        ethPriceFeed.updatePrice(int256(newPrice));
    }
    
    function setBtcPrice(uint256 newPrice) public {
        btcPriceFeed.updatePrice(int256(newPrice));
    }
    
    function setBothPrices(uint256 ethPrice, uint256 btcPrice) public {
        setEthPrice(ethPrice);
        setBtcPrice(btcPrice);
    }
    
    function simulateMarketCrash(uint256 crashPercent) public {
        uint256 newEthPrice = (INITIAL_ETH_PRICE * (100 - crashPercent)) / 100;
        uint256 newBtcPrice = (INITIAL_BTC_PRICE * (100 - crashPercent)) / 100;
        setBothPrices(newEthPrice, newBtcPrice);
    }
    
    function simulateMarketPump(uint256 pumpPercent) public {
        uint256 newEthPrice = (INITIAL_ETH_PRICE * (100 + pumpPercent)) / 100;
        uint256 newBtcPrice = (INITIAL_BTC_PRICE * (100 + pumpPercent)) / 100;
        setBothPrices(newEthPrice, newBtcPrice);
    }
    
    function simulatePriceFeedFailure() public {
        ethPriceFeed.setShouldRevert(true);
        btcPriceFeed.setShouldRevert(true);
    }
    
    function restorePriceFeeds() public {
        ethPriceFeed.setShouldRevert(false);
        btcPriceFeed.setShouldRevert(false);
        setBothPrices(INITIAL_ETH_PRICE, INITIAL_BTC_PRICE);
    }
    
    function simulateStalePrice() public {
        ethPriceFeed.setStalePrice(true);
        btcPriceFeed.setStalePrice(true);
    }
    
    // ==================== Test Scenario Helpers ====================
    
    function startScenario(string memory scenarioName) public {
        console2.log("\n=== Starting Scenario:", scenarioName, "===");
        emit TestScenarioStarted(scenarioName);
    }
    
    function endScenario(string memory scenarioName) public {
        console2.log("=== Completed Scenario:", scenarioName, "===");
        emit TestScenarioCompleted(scenarioName);
    }
    
    function logPosition(address user, uint256 collateral, uint256 debt, uint256 healthFactor) public {
        console2.log("Position for", user);
        console2.log("  Collateral:", collateral);
        console2.log("  Debt:", debt);
        console2.log("  Health Factor:", healthFactor);
        console2.log("  Is Healthy:", isHealthFactorOk(healthFactor));
    }
    
    // ==================== Assertion Helpers ====================
    
    function assertHealthyPosition(uint256 healthFactor) public {
        assertTrue(isHealthFactorOk(healthFactor), "Position should be healthy");
    }
    
    function assertUnhealthyPosition(uint256 healthFactor) public {
        assertTrue(isUndercollateralized(healthFactor), "Position should be unhealthy");
    }
    
    function assertApproxEqAbsCustom(uint256 a, uint256 b, uint256 maxDelta, string memory err) public pure {
        uint256 delta = a > b ? a - b : b - a;
        assertTrue(delta <= maxDelta, err);
    }
    
    function assertApproxEqRelCustom(uint256 a, uint256 b, uint256 maxPercentDelta, string memory err) public pure {
        if (a == 0 && b == 0) return;
        uint256 percentDelta = a > b ? ((a - b) * 1e18) / a : ((b - a) * 1e18) / b;
        assertTrue(percentDelta <= maxPercentDelta, err);
    }
    
    // ==================== Emergency and Edge Case Helpers ====================
    
    function drainUserTokens(address user) public {
        uint256 wethBalance = wethMock.balanceOf(user);
        uint256 wbtcBalance = wbtcMock.balanceOf(user);
        
        vm.startPrank(user);
        if (wethBalance > 0) wethMock.transfer(address(0xdead), wethBalance);
        if (wbtcBalance > 0) wbtcMock.transfer(address(0xdead), wbtcBalance);
        vm.stopPrank();
    }
    
    function createLiquidatablePosition(
        address user,
        uint256 collateralAmount,
        uint256 mintAmount,
        uint256 priceDropPercent
    ) public returns (uint256 initialHealthFactor, uint256 finalHealthFactor) {
        // This will be implemented by child contracts based on their specific engine
        return (0, 0);
    }
    
    // ==================== Gas Tracking Helpers ====================
    
    uint256 private gasStart;
    
    function startGasTracking() public {
        gasStart = gasleft();
    }
    
    function endGasTracking(string memory operationName) public {
        uint256 gasUsed = gasStart - gasleft();
        console2.log("Gas used for", operationName, ":", gasUsed);
    }
    
    // ==================== Fuzzing Helpers ====================
    
    function boundCollateralAmount(uint256 amount) public pure returns (uint256) {
        return bound(amount, 1e16, 1000e18); // 0.01 to 1000 tokens
    }
    
    function boundMintAmount(uint256 amount) public pure returns (uint256) {
        return bound(amount, 1e18, 100000e18); // 1 to 100000 stablecoins
    }
    
    function boundPrice(uint256 price) public pure returns (uint256) {
        return bound(price, 1e6, 1e12); // $10 to $10,000,000 (with 8 decimals)
    }
    
    function boundHealthFactor(uint256 hf) public pure returns (uint256) {
        return bound(hf, 1e17, 10e18); // 0.1 to 10.0
    }
    
    // ==================== Mock Contract Management ====================
    
    function resetPriceFeeds() public {
        ethPriceFeed.updatePrice(int256(INITIAL_ETH_PRICE));
        btcPriceFeed.updatePrice(int256(INITIAL_BTC_PRICE));
        ethPriceFeed.setShouldRevert(false);
        btcPriceFeed.setShouldRevert(false);
        ethPriceFeed.setStalePrice(false);
        btcPriceFeed.setStalePrice(false);
    }
    
    function resetUserBalances() public {
        _mintTokensToUsers();
    }
    
    function resetAllState() public {
        resetPriceFeeds();
        resetUserBalances();
        advanceTime(0); // Reset to current timestamp
    }
}