// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {stablecoinWBTCEngine} from "../src/StablecoinWBTCEngine.sol";
import {StableCoinWBTC} from "../src/StablecoinWBTC.sol";
import {TestSetup} from "./TestSetup.sol";

/**
 * @title StablecoinWBTCEngineTest
 * @dev Comprehensive tests for StablecoinWBTCEngine.sol contract
 * Tests collateral management, minting, burning, liquidation, and health factor calculations
 */
contract StablecoinWBTCEngineTest is TestSetup {
    stablecoinWBTCEngine public engine;
    StableCoinWBTC public stableCoinWBTC;
    
    // Test constants
    uint256 constant COLLATERAL_AMOUNT = 2e18; // 2 WBTC
    uint256 constant MINT_AMOUNT = 75000e18; // $75,000 worth of stablecoins
    uint256 constant LARGE_COLLATERAL = 10e18; // 10 WBTC
    
    function setUp() public override {
        super.setUp();
        
        // Deploy StableCoinWBTC first
        stableCoinWBTC = new StableCoinWBTC();
        
        // Deploy stablecoinWBTCEngine
        engine = new stablecoinWBTCEngine(
            address(stableCoinWBTC),
            address(wbtcMock),
            address(btcPriceFeed)
        );
        
        vm.label(address(engine), "stablecoinWBTCEngine");
        vm.label(address(stableCoinWBTC), "StableCoinWBTC");
        
        // Give users some WBTC and set up approvals
        vm.startPrank(user1);
        wbtcMock.approve(address(engine), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(user2);
        wbtcMock.approve(address(engine), type(uint256).max);
        vm.stopPrank();
        
        vm.startPrank(liquidator);
        wbtcMock.approve(address(engine), type(uint256).max);
        stableCoinWBTC.approve(address(engine), type(uint256).max);
        vm.stopPrank();
    }
    
    /* ==================== Constructor Tests ==================== */
    
    function testConstructor() public view {
        assertEq(address(engine.stablecoinWBTC()), address(stableCoinWBTC));
        assertEq(address(engine.wbtc()), address(wbtcMock));
        assertEq(address(engine.priceFeed()), address(btcPriceFeed));
    }
    
    /* ==================== Price Feed Tests ==================== */
    
    function testGetLatestPrice() public view {
        uint256 price = engine.getLatestPrice();
        assertEq(price, INITIAL_BTC_PRICE);
    }
    
    function testGetLatestPriceAfterUpdate() public {
        uint256 newPrice = 60000e8;
        btcPriceFeed.updatePrice(int256(newPrice));
        
        uint256 price = engine.getLatestPrice();
        assertEq(price, newPrice);
    }
    
    function testGetLatestPriceInvalidPrice() public {
        btcPriceFeed.updatePrice(-1);
        
        vm.expectRevert("Invalid price");
        engine.getLatestPrice();
    }
    
    function testGetLatestPriceZeroPrice() public {
        btcPriceFeed.updatePrice(0);
        
        vm.expectRevert("Invalid price");
        engine.getLatestPrice();
    }
    
    /* ==================== Deposit Collateral Tests ==================== */
    
    function testDepositCollateral() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(wbtcMock.balanceOf(address(engine)), COLLATERAL_AMOUNT);
        assertEq(wbtcMock.balanceOf(user1), INITIAL_TOKEN_SUPPLY - COLLATERAL_AMOUNT);
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
        uint256 firstDeposit = 1e18;
        uint256 secondDeposit = 0.5e18;
        
        vm.startPrank(user1);
        engine.depositCollateral(firstDeposit);
        engine.depositCollateral(secondDeposit);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), firstDeposit + secondDeposit);
    }
    
    function testDepositCollateralNoApproval() public {
        vm.startPrank(user2);
        wbtcMock.approve(address(engine), 0); // Remove approval
        vm.expectRevert(); // Updated for newer OpenZeppelin
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
    }
    
    /* ==================== Deposit and Mint Tests ==================== */
    
    function testDepositCollateralAndMintstablecoinWBTC() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(engine.stablecoinWBTCHoldings(user1), MINT_AMOUNT);
        assertEq(stableCoinWBTC.balanceOf(user1), MINT_AMOUNT);
        assertEq(wbtcMock.balanceOf(address(engine)), COLLATERAL_AMOUNT);
    }
    
    function testDepositAndMintZeroCollateral() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount must be greater than zero");
        engine.depositCollateralAndMintstablecoinWBTC(0, MINT_AMOUNT);
        vm.stopPrank();
    }
    
    function testDepositAndMintZeroMintAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Mint amount must be greater than zero");
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, 0);
        vm.stopPrank();
    }
    
    function testDepositAndMintInsufficientCollateral() public {
        uint256 insufficientMint = 125000e18; // More than collateral value
        
        vm.startPrank(user1);
        vm.expectRevert("Insufficient collateral value");
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, insufficientMint);
        vm.stopPrank();
    }
    
    function testDepositAndMintExactCollateralValue() public {
        uint256 exactMintAmount = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_BTC_PRICE);
        
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, exactMintAmount);
        vm.stopPrank();
        
        assertEq(engine.stablecoinWBTCHoldings(user1), exactMintAmount);
    }
    
    /* ==================== Burn and Withdraw Tests ==================== */
    
    function testBurnstablecoinWBTCAndWithdrawCollateral() public {
        // First deposit and mint
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        // Then burn and withdraw
        uint256 burnAmount = 25000e18;
        uint256 withdrawAmount = 0.5e18;
        
        // User must have the tokens in their balance to burn them
        stableCoinWBTC.approve(address(engine), burnAmount);
        engine.burnstablecoinWBTCAndWithdrawCollateral(burnAmount, withdrawAmount);
        vm.stopPrank();
        
        assertEq(engine.stablecoinWBTCHoldings(user1), MINT_AMOUNT - burnAmount);
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT - withdrawAmount);
        assertEq(wbtcMock.balanceOf(user1), INITIAL_TOKEN_SUPPLY - COLLATERAL_AMOUNT + withdrawAmount);
    }
    
    function testBurnAndWithdrawInsufficientHoldings() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Insufficient stablecoinWBTC holdings to burn");
        engine.burnstablecoinWBTCAndWithdrawCollateral(MINT_AMOUNT + 1, 0.1e18);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawZeroBurn() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Burn amount must be greater than zero");
        engine.burnstablecoinWBTCAndWithdrawCollateral(0, 0.1e18);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawZeroWithdraw() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        vm.expectRevert("Withdraw amount must be greater than zero");
        engine.burnstablecoinWBTCAndWithdrawCollateral(10000e18, 0);
        vm.stopPrank();
    }
    
    function testBurnAndWithdrawInsufficientBurnForWithdraw() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        uint256 smallBurn = 5000e18;
        uint256 largeWithdraw = 1e18; // Worth more than burn amount
        
        vm.expectRevert("Insufficient burn amount for the requested");
        engine.burnstablecoinWBTCAndWithdrawCollateral(smallBurn, largeWithdraw);
        vm.stopPrank();
    }
    
    /* ==================== Collateral Value Tests ==================== */
    
    function testGetCollateralValue() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        uint256 expectedValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_BTC_PRICE);
        uint256 actualValue = engine.getCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testGetCollateralValueAfterPriceChange() public {
        vm.startPrank(user1);
        engine.depositCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        
        uint256 newPrice = 60000e8;
        btcPriceFeed.updatePrice(int256(newPrice));
        
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
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        uint256 collateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_BTC_PRICE);
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
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        // Price drops
        uint256 newPrice = 35000e8;
        btcPriceFeed.updatePrice(int256(newPrice));
        
        uint256 newCollateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, newPrice);
        uint256 expectedHealthFactor = calculateHealthFactor(newCollateralValue, MINT_AMOUNT);
        uint256 actualHealthFactor = engine.calculateHealthFactor(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
    
    /* ==================== Liquidation Tests ==================== */
    
    function testLiquidation() public {
        // Setup position that will become unhealthy
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(LARGE_COLLATERAL, 375000e18); // High debt
        vm.stopPrank();
        
        // Price drops to make position unhealthy
        btcPriceFeed.updatePrice(25000e8); // $25,000 per BTC
        
        // Verify health factor is below threshold
        uint256 healthFactor = engine.calculateHealthFactor(user1);
        assertLt(healthFactor, HEALTH_FACTOR_THRESHOLD);
        
        // Give liquidator some stablecoins to burn
        stableCoinWBTC.mint(liquidator, 100000e18);
        
        uint256 debtToCover = 50000e18;
        uint256 expectedCollateralSeized = (debtToCover * 1e8) / engine.getLatestPrice();
        
        vm.startPrank(liquidator);
        stableCoinWBTC.approve(address(engine), debtToCover);
        engine.liquidate(user1, debtToCover);
        vm.stopPrank();
        
        assertEq(engine.stablecoinWBTCHoldings(user1), 375000e18 - debtToCover);
        assertEq(engine.collateralDeposits(user1), LARGE_COLLATERAL - expectedCollateralSeized);
        assertEq(wbtcMock.balanceOf(liquidator), INITIAL_TOKEN_SUPPLY + expectedCollateralSeized);
    }
    
    function testLiquidationInvalidUser() public {
        vm.startPrank(liquidator);
        vm.expectRevert("Invalid user address");
        engine.liquidate(address(0), 1000e18);
        vm.stopPrank();
    }
    
    function testLiquidationZeroDebt() public {
        vm.startPrank(liquidator);
        vm.expectRevert("Debt to cover must be greater than zero");
        engine.liquidate(user1, 0);
        vm.stopPrank();
    }
    
    function testLiquidationExcessiveDebt() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        btcPriceFeed.updatePrice(25000e8); // Make unhealthy
        
        vm.startPrank(liquidator);
        vm.expectRevert("User debt is less than the amount to cover");
        engine.liquidate(user1, MINT_AMOUNT + 1);
        vm.stopPrank();
    }
    
    function testLiquidationInsufficientCollateral() public {
        // Create position with very little collateral but high debt
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(0.1e18, 2000e18); // 0.1 WBTC, 2000 stablecoins
        vm.stopPrank();
        
        btcPriceFeed.updatePrice(10000e8); // Very low price
        
        stableCoinWBTC.mint(liquidator, 10000e18);
        
        vm.startPrank(liquidator);
        vm.expectRevert("Not enough collateral to seize");
        engine.liquidate(user1, 5000e18); // Too much to liquidate
        vm.stopPrank();
    }
    
    /* ==================== User Details Tests ==================== */
    
    function testGetUserDetails() public {
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = engine.getUserDetails(user1);
        
        uint256 expectedCollateralValue = calculateCollateralValue(COLLATERAL_AMOUNT, INITIAL_BTC_PRICE);
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
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        
        // 3. Partial burn and withdraw (user needs to approve burn)
        stableCoinWBTC.approve(address(engine), 25000e18);
        engine.burnstablecoinWBTCAndWithdrawCollateral(25000e18, 0.4e18);
        
        // 4. Check final state
        assertEq(engine.collateralDeposits(user1), (2 * COLLATERAL_AMOUNT) - 0.4e18);
        assertEq(engine.stablecoinWBTCHoldings(user1), MINT_AMOUNT - 25000e18);
        vm.stopPrank();
    }
    
    function testMultipleUsersInteraction() public {
        // User1 creates position
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT, MINT_AMOUNT);
        vm.stopPrank();
        
        // User2 creates different position
        vm.startPrank(user2);
        engine.depositCollateralAndMintstablecoinWBTC(COLLATERAL_AMOUNT * 2, MINT_AMOUNT / 2);
        vm.stopPrank();
        
        // Verify independent positions
        assertEq(engine.collateralDeposits(user1), COLLATERAL_AMOUNT);
        assertEq(engine.collateralDeposits(user2), COLLATERAL_AMOUNT * 2);
        assertEq(engine.stablecoinWBTCHoldings(user1), MINT_AMOUNT);
        assertEq(engine.stablecoinWBTCHoldings(user2), MINT_AMOUNT / 2);
    }
    
    /* ==================== Comparison with ETH Engine Tests ==================== */
    
    function testHigherCollateralValueThanETH() public {
        // BTC should generally have higher value than ETH
        uint256 sameCollateralAmount = 1e18;
        uint256 btcValue = calculateCollateralValue(sameCollateralAmount, INITIAL_BTC_PRICE);
        uint256 ethValue = calculateCollateralValue(sameCollateralAmount, INITIAL_ETH_PRICE);
        
        assertGt(btcValue, ethValue);
    }
    
    /* ==================== Fuzz Tests ==================== */
    
    function testFuzzDepositCollateral(uint256 amount) public {
        vm.assume(amount > 0);
        vm.assume(amount <= INITIAL_TOKEN_SUPPLY);
        
        vm.startPrank(user1);
        engine.depositCollateral(amount);
        vm.stopPrank();
        
        assertEq(engine.collateralDeposits(user1), amount);
        assertEq(wbtcMock.balanceOf(address(engine)), amount);
    }
    
    function testFuzzGetCollateralValue(uint256 collateralAmount, uint256 price) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_TOKEN_SUPPLY);
        vm.assume(price > 0 && price <= type(uint256).max / collateralAmount); // Prevent overflow
        
        btcPriceFeed.updatePrice(int256(price));
        
        vm.startPrank(user1);
        engine.depositCollateral(collateralAmount);
        vm.stopPrank();
        
        uint256 expectedValue = (collateralAmount * price) / 1e8;
        uint256 actualValue = engine.getCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testFuzzHealthFactorCalculation(uint256 collateralAmount, uint256 debt) public {
        vm.assume(collateralAmount > 0 && collateralAmount <= INITIAL_TOKEN_SUPPLY);
        vm.assume(debt > 0 && debt <= type(uint256).max / 1e18); // Prevent overflow
        
        uint256 collateralValue = calculateCollateralValue(collateralAmount, INITIAL_BTC_PRICE);
        vm.assume(collateralValue >= debt); // Ensure sufficient collateral
        
        vm.startPrank(user1);
        engine.depositCollateralAndMintstablecoinWBTC(collateralAmount, debt);
        vm.stopPrank();
        
        uint256 expectedHealthFactor = calculateHealthFactor(collateralValue, debt);
        uint256 actualHealthFactor = engine.calculateHealthFactor(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
}