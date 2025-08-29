// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StableCoinEngine} from "../src/StableCoinEngine.sol";
import {StableCoin} from "../src/Stablecoin.sol";
import {TestSetup} from "./TestSetup.sol";

/**
 * @title StableCoinEngineTest
 * @dev Comprehensive tests for StableCoinEngine.sol contract
 * Tests collateral management, minting, burning, liquidation, health factor calculations, and edge cases
 * Includes stress testing, security checks, and invariant validation
 */
contract StableCoinEngineTest is TestSetup {
    StableCoinEngine public engine;
    StableCoin public stableCoin;
    
    // Test constants
    uint256 constant COLLATERAL_AMOUNT = 10e18; // 10 WETH
    uint256 constant MINT_AMOUNT = 13000e18; // $13,000 worth of stablecoins (safe ratio)
    uint256 constant LARGE_COLLATERAL = 100e18; // 100 WETH
    uint256 constant LIQUIDATION_AMOUNT = 5000e18; // Amount for liquidation tests
    
    // Events to test
    event CollateralDeposited(address indexed user, uint256 amount);
    event StableCoinMinted(address indexed user, uint256 amount);
    event StableCoinBurned(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event UserLiquidated(address indexed liquidator, address indexed user, uint256 debtCovered, uint256 collateralSeized);
    
    function setUp() public override {
        super.setUp();
        
        // Deploy StableCoin first
        stableCoin = new StableCoin();
        
        // Deploy StableCoinEngine
        engine = new StableCoinEngine(
            address(stableCoin),
            address(wethMock),
            address(ethPriceFeed)
        );
        
        vm.label(address(engine), "StableCoinEngine");
        vm.label(address(stableCoin), "StableCoin");
        
        // Setup approvals for all test users
        _setupUserApprovals();
        
        console2.log("\n=== StableCoinEngine Test Setup ===");
        console2.log("Engine deployed at:", address(engine));
        console2.log("StableCoin deployed at:", address(stableCoin));
        console2.log("Initial ETH Price:", engine.getLatestPrice());
    }
    
    function _setupUserApprovals() internal {
        address[] memory users = new address[](6);
        users[0] = user1;
        users[1] = user2;
        users[2] = user3;
        users[3] = liquidator;
        users[4] = owner;
        users[5] = attacker;
        
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            wethMock.approve(address(engine), type(uint256).max);
            stableCoin.approve(address(engine), type(uint256).max);
            vm.stopPrank();
        }
    }
    
    /* ==================== Constructor and Initial State Tests ==================== */
    
    function testConstructor() public {
        assertEq(address(engine.stableCoin()), address(stableCoin), "StableCoin address should be correct");
        assertEq(address(engine.weth()), address(wethMock), "WETH address should be correct");
        assertEq(address(engine.priceFeed()), address(ethPriceFeed), "Price feed address should be correct");
    }
    
    function testInitialUserState() public {
        // Check initial collateral deposits are zero
        assertEq(engine.collateralDeposits(user1), 0, "Initial collateral should be zero");
        assertEq(engine.collateralDeposits(user2), 0, "Initial collateral should be zero");
        
        // Check initial stablecoin holdings are zero
        assertEq(engine.stableCoinHoldings(user1), 0, "Initial holdings should be zero");
        assertEq(engine.stableCoinHoldings(user2), 0, "Initial holdings should be zero");
        
        // Check initial health factors are max (no debt)
        assertEq(engine.calculateHealthFactor(user1), type(uint256).max, "Initial health factor should be max");
        assertEq(engine.calculateHealthFactor(user2), type(uint256).max, "Initial health factor should be max");
    }
    
    /* ==================== Price Feed Tests ==================== */
    
    function testGetLatestPrice() public {
        uint256 price = engine.getLatestPrice();
        assertEq(price, INITIAL_ETH_PRICE, "Should return initial ETH price");
    }
    
    function testGetLatestPriceAfterUpdate() public {
        startScenario("Price Update");
        
        uint256 newPrice = 2500e8;
        ethPriceFeed.updatePrice(int256(newPrice));
        
        uint256 price = engine.getLatestPrice();
        assertEq(price, newPrice, "Should return updated price");
        
        endScenario("Price Update");
    }
    
    function testGetLatestPriceInvalidPrice() public {
        ethPriceFeed.updatePrice(-1);
        
        vm.expectRevert("Invalid price");
        engine.getLatestPrice();
    }
    
    function testGetLatestPriceZeroPrice() public {
        ethPriceFeed.updatePrice(0);
        
        vm.expectRevert("Invalid price");
        engine.getLatestPrice();
    }
    
    function testPriceFeedFailure() public {
        startScenario("Price Feed Failure");
        
        simulatePriceFeedFailure();
        
        vm.expectRevert("Mock price feed reverted");
        engine.getLatestPrice();
        
        endScenario("Price Feed Failure");
    }
    
    /* ==================== Deposit Collateral Tests ==================== */
    
    function testDepositCollateral() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(wethMock.balanceOf(address(engine)), COLLATERAL_AMOUNT);
        assertEq(wethMock.balanceOf(user1), INITIAL_TOKEN_SUPPLY - COLLATERAL_AMOUNT);
    }
    
    function testDepositCollateralZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than zero");
        engine.depositCollateral(0);
        vm.stopPrank();
    }
    
    function testDepositCollateralInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Updated for newer OpenZeppelin
        engine.depositCollateral(INITIAL_TOKEN_SUPPLY + 1);
        vm.stopPrank();
    }
    
    function testDepositCollateralMultipleTimes() public {
        uint256 firstDeposit = 5e18;
        uint256 secondDeposit = 3e18;
        
        vm.startPrank(user1);
        engine.depositCollateral(firstDeposit);
        engine.depositCollateral(secondDeposit);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), firstDeposit + secondDeposit);
    }
    
    function testDepositCollateralNoApproval() public {
        vm.startPrank(user2);
        wethMock.approve(address(engine), 0); // Remove approval
        vm.expectRevert(); // Updated for newer OpenZeppelin
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
    }
    
    /* ==================== Deposit and Mint Tests ==================== */
    
    function testDepositCollateralAndMintStableCoin() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(engine.stableCoinHoldings(user1), MINT_AMOUNT);
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT);
        assertEq(wethMock.balanceOf(address(engine)), COLLATERAL_AMOUNT);
    }
    
    function testDepositAndMintZeroCollateral() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than zero");
        engine.depositCollateralAndMintStableCoin(0, MINT_AMOUNT);
        vm.stopPrank();
    }
    
    function testDepositAndMintZeroMintAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Mint amount must be greater than zero");
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, 0);
        vm.stopPrank();
    }
    
    function testDepositAndMintInsufficientCollateral() public {
        uint256 insufficientMint = 25000e18; // More than collateral value
        
        vm.startPrank(user1);
        vm.expectRevert("Insufficient collateral value");
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, insufficientMint);
        vm.stopPrank();
    }
    
    function testDepositAndMintExactCollateralValue() public {
        uint256 exactMintAmount = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_ETH_PRICE);
        
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, exactMintAmount);
        vm.stopPrank();
        
        assertEq(engine.stableCoinHoldings(user1), exactMintAmount);
    }
    
    /* ==================== Burn and Withdraw Tests ==================== */
    
    function testBurnStableCoinAndWithdrawCollateral() public {
        // First deposit and mint
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        // Then burn and withdraw
        uint256 burnAmount = 5000e18;
        uint256 withdrawAmount = 3e18;
        
        // User must have the tokens in their balance to burn them
        stableCoin.approve(address(engine), burnAmount);
        engine.burnStableCoinAndWithdrawCollateral(burnAmount, withdrawAmount);
        vm.stopPrank();
        
        assertEq(engine.stableCoinHoldings(user1), MINT_AMOUNT - burnAmount);
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT - withdrawAmount);
        assertEq(wethMock.balanceOf(user1), INITIAL_TOKEN_SUPPLY - COLLATERAL_AMOUNT + withdrawAmount);
    }
    
    function testBurnAndWithdrawInsufficientHoldings() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Insufficient stablecoin holdings to burn");
        engine.burnStableCoinAndWithdrawCollateral(MINT_AMOUNT + 1, 1e18);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawZeroBurn() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Burn amount must be greater than zero");
        engine.burnStableCoinAndWithdrawCollateral(0, 1e18);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawZeroWithdraw() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Withdraw amount must be greater than zero");
        engine.burnStableCoinAndWithdrawCollateral(1000e18, 0);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawInsufficientBurnForWithdraw() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        uint256 smallBurn = 1000e18;
        uint256 largeWithdraw = 5e18; // Worth more than burn amount
        
        vm.expectRevert("Insufficient burn amount for the requested withdrawal");
        engine.burnStableCoinAndWithdrawCollateral(smallBurn, largeWithdraw);
        vm.stopPrank();
    }
    
    /* ==================== Collateral Value Tests ==================== */
    
    function testGetCollateralValue() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        uint256 expectedValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_ETH_PRICE);
        uint256 actualValue = engine.getCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testGetCollateralValueAfterPriceChange() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        uint256 newPrice = 2500e8;
        ethPriceFeed.updatePrice(int256(newPrice));
        
        uint256 expectedValue = calculateCollateralValue(COLLATERAL_AMOUNT, newPrice);
        uint256 actualValue = engine.getCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testGetCollateralValueZeroDeposits() public view {
        uint256 value = engine.getCollateralValue(user1);
        assertEq(value, 0);
    }
    
    /* ==================== Health Factor Tests ==================== */
    
    function testCalculateHealthFactor() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        uint256 collateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_ETH_PRICE);
        uint256 expectedHealthFactor = calculateHealthFactor(collateralValue, MINT_AMOUNT);
        uint256 actualHealthFactor = engine.calculateHealthFactor(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
    
    function testCalculateHealthFactorZeroDebt() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        uint256 healthFactor = engine.calculateHealthFactor(user1);
        assertEq(healthFactor, type(uint256).max);
    }
    
    function testCalculateHealthFactorAfterPriceChange() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        // Price drops
        uint256 newPrice = 1500e8;
        ethPriceFeed.updatePrice(int256(newPrice));
        
        uint256 newCollateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, newPrice);
        uint256 expectedHealthFactor = calculateHealthFactor(newCollateralValue, MINT_AMOUNT);
        uint256 actualHealthFactor = engine.calculateHealthFactor(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
    
    /* ==================== Liquidation Tests ==================== */
    
    function testLiquidation() public {
        // Setup position that will become unhealthy
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(LARGE_COLLATERAL, 150000e18); // High debt
        vm.stopPrank();
        
        // Price drops to make position unhealthy
        ethPriceFeed.updatePrice(1000e8); // $1000 per ETH
        
        // Verify health factor is below threshold
        uint256 healthFactor = engine.calculateHealthFactor(user1);
        assertLt(healthFactor, HEALTH_FACTOR_THRESHOLD);
        
        // Give liquidator some stablecoins to burn
        stableCoin.mint(liquidator, 50000e18);
        
        uint256 debtToCover = 10000e18;
        uint256 expectedCollateralSeized = (debtToCover * 1e8) / engine.getLatestPrice();
        
        vm.startPrank(liquidator);
        stableCoin.approve(address(engine), debtToCover);
        engine.liquidate(user1, debtToCover);
        vm.stopPrank();
        
        assertEq(engine.stableCoinHoldings(user1), 150000e18 - debtToCover);
        assertEq(engine.collateralDeposits(user1), LARGE_COLLATERAL - expectedCollateralSeized);
        assertEq(wethMock.balanceOf(liquidator), INITIAL_TOKEN_SUPPLY + expectedCollateralSeized);
    }
    
    function testLiquidationHealthyPosition() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        // Position is healthy, liquidation should fail
        uint256 healthFactor = engine.calculateHealthFactor(user1);
        assertTrue(healthFactor >= HEALTH_FACTOR_THRESHOLD); // Use assertTrue instead of assertGe
        
        stableCoin.mint(liquidator, 10000e18);
        
        vm.startPrank(liquidator);
        vm.expectRevert("Health factor is ok");
        engine.liquidate(user1, 1000e18);
        vm.stopPrank();
    }
    
    function testLiquidationZeroDebt() public {
        // Create unhealthy position first
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(LARGE_COLLATERAL, 150000e18);
        vm.stopPrank();
        
        ethPriceFeed.updatePrice(1000e8);
        
        vm.startPrank(liquidator);
        vm.expectRevert("Debt to cover must be greater than zero");
        engine.liquidate(user1, 0);
        vm.stopPrank();
    }
    
    function testLiquidationExcessiveDebt() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        ethPriceFeed.updatePrice(1000e8); // Make unhealthy
        
        vm.startPrank(liquidator);
        vm.expectRevert("User debt is less than the amount to cover");
        engine.liquidate(user1, MINT_AMOUNT + 1);
        vm.stopPrank();
    }
    
    function testLiquidationInsufficientCollateral() public {
        // Create position with very little collateral but high debt
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(1e18, 1000e18); // 1 WETH, 1000 stablecoins
        vm.stopPrank();
        
        ethPriceFeed.updatePrice(500e8); // Very low price
        
        stableCoin.mint(liquidator, 10000e18);
        
        vm.startPrank(liquidator);
        vm.expectRevert("Not enough collateral to seize");
        engine.liquidate(user1, 5000e18); // Too much to liquidate
        vm.stopPrank();
    }
    
    /* ==================== User Details Tests ==================== */
    
    function testGetUserDetails() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = engine.getUserDetails(user1);
        
        uint256 expectedCollateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_ETH_PRICE);
        uint256 expectedHealthFactor = calculateHealthFactor(expectedCollateralValue, MINT_AMOUNT);
        
        assertEq(collateralValue, expectedCollateralValue);
        assertEq(debt, MINT_AMOUNT);
        assertEq(healthFactor, expectedHealthFactor);
    }
    
    function testGetUserDetailsNoPosition() public view {
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = engine.getUserDetails(user1);
        
        assertEq(collateralValue, 0);
        assertEq(debt, 0);
        assertEq(healthFactor, type(uint256).max);
    }
    
    /* ==================== Integration Tests ==================== */
    
    function testCompleteUserFlow() public {
        // 1. Deposit collateral
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        
        // 2. Mint stablecoins
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        // 3. Partial burn and withdraw (user needs to approve burn)
        stableCoin.approve(address(engine), 5000e18);
        engine.burnStableCoinAndWithdrawCollateral(5000e18, 2e18);
        
        // 4. Check final state
        assertEq(engine.collateralDeposits(user1), (2 * COLLATERAL_AMOUNT) - 2e18);
        assertEq(engine.stableCoinHoldings(user1), MINT_AMOUNT - 5000e18);
        vm.stopPrank();
    }
    
    function testMultipleUsersInteraction() public {
        // User1 creates position
        vm.startPrank(user1);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        // User2 creates different position
        vm.startPrank(user2);
        engine.depositCollateralAndMintStableCoin(COLLATERAL_AMOUNT * 2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Verify independent positions
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(engine.collateralDeposits(user2), COLLATERAL_AMOUNT * 2);
        assertEq(engine.stableCoinHoldings(user1), MINT_AMOUNT);
        assertEq(engine.stableCoinHoldings(user2), MINT_AMOUNT / 2);
    }
    
    /* ==================== Fuzz Tests ==================== */
    
    function testFuzzDepositCollateral(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= INITIAL_TOKEN_SUPPLY);
        
        vm.startPrank(user1);
        engine.depositCollateral(amount);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), amount);
        assertEq(wethMock.balanceOf(address(engine)), amount);
    }
    
    function testFuzzGetCollateralValue(uint256 collateralAmount, uint256 price) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_TOKEN_SUPPLY);
        vm.assume(price > 0 && price <= type(uint256).max / collateralAmount); // Prevent overflow
        
        ethPriceFeed.updatePrice(int256(price));
        
        vm.startPrank(user1);
        engine.depositCollateral(collateralAmount);
        vm.stopPrank();
        
        uint256 expectedValue = (collateralAmount * price) / 1e8;
        uint256 actualValue = engine.getCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
}