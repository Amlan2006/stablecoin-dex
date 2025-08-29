// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {DEX} from "../src/DEX.sol";
import {StableCoinEngine} from "../src/StableCoinEngine.sol";
import {stablecoinWBTCEngine} from "../src/StablecoinWBTCEngine.sol";
import {StableCoin} from "../src/Stablecoin.sol";
import {StableCoinWBTC} from "../src/StablecoinWBTC.sol";
import {TestSetup} from "./TestSetup.sol";

/**
 * @title DEXTest
 * @dev Comprehensive tests for DEX.sol contract
 * Tests swapping functionality, wrapper functions, integration between engines, and complex scenarios
 */
contract DEXTest is TestSetup {
    DEX public dex;
    StableCoinEngine public ethEngine;
    stablecoinWBTCEngine public btcEngine;
    StableCoin public stableCoin;
    StableCoinWBTC public stableCoinWBTC;
    
    // Test constants
    uint256 constant ETH_COLLATERAL = 10e18; // 10 WETH
    uint256 constant BTC_COLLATERAL = 2e18; // 2 WBTC
    uint256 constant ETH_MINT = 15000e18; // $15,000 worth
    uint256 constant BTC_MINT = 75000e18; // $75,000 worth
    uint256 constant SWAP_AMOUNT = 5000e18;
    
    function setUp() public override {
        super.setUp();
        
        // Deploy token contracts
        stableCoin = new StableCoin();
        stableCoinWBTC = new StableCoinWBTC();
        
        // Deploy engine contracts
        ethEngine = new StableCoinEngine(
            address(stableCoin),
            address(wethMock),
            address(ethPriceFeed)
        );
        
        btcEngine = new stablecoinWBTCEngine(
            address(stableCoinWBTC),
            address(wbtcMock),
            address(btcPriceFeed)
        );
        
        // Deploy DEX contract
        dex = new DEX(
            address(btcEngine),
            address(ethEngine),
            address(stableCoin),
            address(stableCoinWBTC)
        );
        
        // Label contracts
        vm.label(address(dex), "DEX");
        vm.label(address(ethEngine), "ETH_Engine");
        vm.label(address(btcEngine), "BTC_Engine");
        vm.label(address(stableCoin), "sETH");
        vm.label(address(stableCoinWBTC), "sBTC");
        
        // Setup user approvals for all tokens and engines
        _setupUserApprovals();
        
        // Give DEX some initial liquidity for swaps
        _setupDEXLiquidity();
    }
    
    function _setupUserApprovals() internal {
        address[3] memory users = [user1, user2, liquidator];
        
        for (uint i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            // Token approvals for engines (DEX wrapper functions call engines directly)
            wethMock.approve(address(ethEngine), type(uint256).max);
            wbtcMock.approve(address(btcEngine), type(uint256).max);
            
            // Token approvals for DEX (for swapping)
            stableCoin.approve(address(dex), type(uint256).max);
            stableCoinWBTC.approve(address(dex), type(uint256).max);
            
            // Engine approvals for liquidation
            stableCoin.approve(address(ethEngine), type(uint256).max);
            stableCoinWBTC.approve(address(btcEngine), type(uint256).max);
            vm.stopPrank();
        }
    }
    
    function _setupDEXLiquidity() internal {
        // Mint some tokens to DEX for swapping
        stableCoin.mint(address(dex), 100000e18);
        stableCoinWBTC.mint(address(dex), 100000e18);
    }
    
    /* ==================== Constructor Tests ==================== */
    
    function testConstructor() public view {
        assertEq(address(dex.stablecoinWBTCEngineContract()), address(btcEngine));
        assertEq(address(dex.stableCoinEngineContract()), address(ethEngine));
        assertEq(address(dex.stablecoin()), address(stableCoin));
        assertEq(address(dex.stablecoinWbtc()), address(stableCoinWBTC));
    }
    
    /* ==================== Engine Wrapper Tests ==================== */
    
    function testDepositWETHCollateralAndMintStableCoin() public {
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        vm.stopPrank();
        
        assertEq(ethEngine.collateralDeposits(user1), ETH_COLLATERAL);
        assertEq(ethEngine.stableCoinHoldings(user1), ETH_MINT);
        assertEq(stableCoin.balanceOf(user1), ETH_MINT);
    }
    
    function testDepositWBTCCollateralAndMintstablecoinWBTC() public {
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        vm.stopPrank();
        
        assertEq(btcEngine.collateralDeposits(user1), BTC_COLLATERAL);
        assertEq(btcEngine.stablecoinWBTCHoldings(user1), BTC_MINT);
        assertEq(stableCoinWBTC.balanceOf(user1), BTC_MINT);
    }
    
    function testGetWETHCollateralValue() public {
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        vm.stopPrank();
        
        uint256 expectedValue = calculateCollateralValue(ETH_COLLATERAL, INITIAL_ETH_PRICE);
        uint256 actualValue = dex.getWETHCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testGetWBTCCollateralValue() public {
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        vm.stopPrank();
        
        uint256 expectedValue = calculateCollateralValue(BTC_COLLATERAL, INITIAL_BTC_PRICE);
        uint256 actualValue = dex.getWBTCCollateralValue(user1);
        
        assertEq(actualValue, expectedValue);
    }
    
    function testCalculateHealthFactorWETH() public {
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        vm.stopPrank();
        
        uint256 expectedHealthFactor = ethEngine.calculateHealthFactor(user1);
        uint256 actualHealthFactor = dex.calculateHealthFactorWETH(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
    
    function testCalculateHealthFactorWBTC() public {
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        vm.stopPrank();
        
        uint256 expectedHealthFactor = btcEngine.calculateHealthFactor(user1);
        uint256 actualHealthFactor = dex.calculateHealthFactorWBTC(user1);
        
        assertEq(actualHealthFactor, expectedHealthFactor);
    }
    
    /* ==================== Exchange Rate Tests ==================== */
    
    function testGetExchangeRate() public view {
        uint256 priceWETH = ethEngine.getLatestPrice();
        uint256 priceWBTC = btcEngine.getLatestPrice();
        uint256 expectedRate = (priceWBTC * 1e18) / priceWETH;
        
        uint256 actualRate = dex.getExchangeRate();
        assertEq(actualRate, expectedRate);
    }
    
    function testGetExchangeRateAfterPriceChange() public {
        uint256 newETHPrice = 2500e8;
        uint256 newBTCPrice = 60000e8;
        
        ethPriceFeed.updatePrice(int256(newETHPrice));
        btcPriceFeed.updatePrice(int256(newBTCPrice));
        
        uint256 expectedRate = (newBTCPrice * 1e18) / newETHPrice;
        uint256 actualRate = dex.getExchangeRate();
        
        assertEq(actualRate, expectedRate);
    }
    
    function testGetExchangeRateInvalidPrice() public {
        ethPriceFeed.updatePrice(0);
        
        vm.expectRevert("Invalid price");
        dex.getExchangeRate();
    }
    
    /* ==================== Swap Function Tests ==================== */
    
    function testSwapStableCoinForStableCoinWBTC() public {
        // Setup: User needs sETH tokens
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        
        uint256 amountIn = SWAP_AMOUNT;
        uint256 exchangeRate = dex.getExchangeRate();
        uint256 expectedAmountOut = (amountIn * 1e18) / exchangeRate;
        
        uint256 initialSETH = stableCoin.balanceOf(user1);
        uint256 initialSBTC = stableCoinWBTC.balanceOf(user1);
        
        dex.swapStableCoinForStableCoinWBTC(amountIn);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user1), initialSETH - amountIn);
        assertEq(stableCoinWBTC.balanceOf(user1), initialSBTC + expectedAmountOut);
        assertEq(stableCoin.balanceOf(address(dex)), amountIn);
    }
    
    function testSwapStableCoinWBTCForStableCoin() public {
        // Setup: User needs sBTC tokens
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        
        uint256 amountIn = SWAP_AMOUNT;
        uint256 exchangeRate = dex.getExchangeRate();
        uint256 expectedAmountOut = (amountIn * exchangeRate) / 1e18;
        
        uint256 initialSETH = stableCoin.balanceOf(user1);
        uint256 initialSBTC = stableCoinWBTC.balanceOf(user1);
        
        dex.swapStableCoinWBTCForStableCoin(amountIn);
        vm.stopPrank();
        
        assertEq(stableCoinWBTC.balanceOf(user1), initialSBTC - amountIn);
        assertEq(stableCoin.balanceOf(user1), initialSETH + expectedAmountOut);
        assertEq(stableCoinWBTC.balanceOf(address(dex)), amountIn);
    }
    
    function testSwapZeroAmount() public {
        vm.startPrank(user1);
        vm.expectRevert("Amount in must be > 0");
        dex.swapStableCoinForStableCoinWBTC(0);
        vm.stopPrank();
        
        vm.startPrank(user1);
        vm.expectRevert("Amount in must be > 0");
        dex.swapStableCoinWBTCForStableCoin(0);
        vm.stopPrank();
    }
    
    function testSwapInsufficientBalance() public {
        vm.startPrank(user1);
        vm.expectRevert(); // Updated for newer OpenZeppelin
        dex.swapStableCoinForStableCoinWBTC(SWAP_AMOUNT);
        vm.stopPrank();
    }
    
    function testSwapInsufficientDEXLiquidity() public {
        // Drain DEX liquidity
        stableCoin.transfer(address(0x1), stableCoin.balanceOf(address(dex)));
        
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        
        vm.expectRevert("DEX: insufficient sBTC liquidity");
        dex.swapStableCoinForStableCoinWBTC(SWAP_AMOUNT);
        vm.stopPrank();
    }
    
    /* ==================== Round Trip Swap Tests ==================== */
    
    function testRoundTripSwap() public {
        // Setup: User has sETH
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        
        uint256 originalSETH = stableCoin.balanceOf(user1);
        uint256 swapAmount = 1000e18;
        
        // sETH -> sBTC
        dex.swapStableCoinForStableCoinWBTC(swapAmount);
        uint256 sBTCReceived = stableCoinWBTC.balanceOf(user1);
        
        // sBTC -> sETH
        dex.swapStableCoinWBTCForStableCoin(sBTCReceived);
        uint256 finalSETH = stableCoin.balanceOf(user1);
        
        vm.stopPrank();
        
        // Due to exchange rate calculations, final amount should be close but not exact
        assertApproxEqRel(finalSETH, originalSETH, 1e15); // 0.1% tolerance
    }
    
    /* ==================== User Details Tests ==================== */
    
    function testGetUserDetails() public {
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        vm.stopPrank();
        
        (uint256 collateralWETH, uint256 debtWETH, uint256 healthFactorWETH,
         uint256 collateralWBTC, uint256 debtWBTC, uint256 healthFactorWBTC) = dex.getUserDetails(user1);
        
        uint256 expectedETHValue = calculateCollateralValue(ETH_COLLATERAL, INITIAL_ETH_PRICE);
        uint256 expectedBTCValue = calculateCollateralValue(BTC_COLLATERAL, INITIAL_BTC_PRICE);
        
        assertEq(collateralWETH, expectedETHValue);
        assertEq(debtWETH, ETH_MINT);
        assertEq(collateralWBTC, expectedBTCValue);
        assertEq(debtWBTC, BTC_MINT);
        assertGt(healthFactorWETH, 0);
        assertGt(healthFactorWBTC, 0);
    }
    
    function testGetUserDetailsWETH() public {
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        vm.stopPrank();
        
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = dex.getUserDetailsWETH(user1);
        (uint256 expectedCollateral, uint256 expectedDebt, uint256 expectedHF) = ethEngine.getUserDetails(user1);
        
        assertEq(collateralValue, expectedCollateral);
        assertEq(debt, expectedDebt);
        assertEq(healthFactor, expectedHF);
    }
    
    function testGetUserDetailsWBTC() public {
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        vm.stopPrank();
        
        (uint256 collateralValue, uint256 debt, uint256 healthFactor) = dex.getUserDetailsWBTC(user1);
        (uint256 expectedCollateral, uint256 expectedDebt, uint256 expectedHF) = btcEngine.getUserDetails(user1);
        
        assertEq(collateralValue, expectedCollateral);
        assertEq(debt, expectedDebt);
        assertEq(healthFactor, expectedHF);
    }
    
    /* ==================== Liquidation Wrapper Tests ==================== */
    
    function testLiquidateWETH() public {
        // Setup unhealthy position
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, 18000e18); // High debt
        vm.stopPrank();
        
        // Drop price to make unhealthy
        ethPriceFeed.updatePrice(1200e8);
        
        // Give liquidator tokens
        stableCoin.mint(liquidator, 10000e18);
        
        uint256 debtToCover = 5000e18;
        
        vm.startPrank(liquidator);
        dex.liquidateWETH(user1, debtToCover);
        vm.stopPrank();
        
        assertEq(ethEngine.stableCoinHoldings(user1), 18000e18 - debtToCover);
    }
    
    function testLiquidateWBTC() public {
        // Setup unhealthy position
        vm.startPrank(user1);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, 90000e18); // High debt
        vm.stopPrank();
        
        // Drop price to make unhealthy
        btcPriceFeed.updatePrice(30000e8);
        
        // Give liquidator tokens
        stableCoinWBTC.mint(liquidator, 20000e18);
        
        uint256 debtToCover = 10000e18;
        
        vm.startPrank(liquidator);
        dex.liquidateWBTC(user1, debtToCover);
        vm.stopPrank();
        
        assertEq(btcEngine.stablecoinWBTCHoldings(user1), 90000e18 - debtToCover);
    }
    
    /* ==================== Integration Tests ==================== */
    
    function testComplexUserScenario() public {
        vm.startPrank(user1);
        
        // 1. Create positions in both engines
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        dex.depositWBTCCollateralAndMintstablecoinWBTC(BTC_COLLATERAL, BTC_MINT);
        
        // 2. Swap some tokens
        dex.swapStableCoinForStableCoinWBTC(2000e18);
        
        // 3. Check balances
        assertLt(stableCoin.balanceOf(user1), ETH_MINT);
        assertGt(stableCoinWBTC.balanceOf(user1), BTC_MINT);
        
        vm.stopPrank();
    }
    
    function testArbitrageOpportunity() public {
        // Simulate price divergence
        ethPriceFeed.updatePrice(1800e8); // ETH down
        btcPriceFeed.updatePrice(55000e8); // BTC up
        
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, ETH_MINT);
        
        uint256 initialSETH = stableCoin.balanceOf(user1);
        uint256 swapAmount = 5000e18;
        
        // Take advantage of new exchange rate
        dex.swapStableCoinForStableCoinWBTC(swapAmount);
        uint256 sBTCReceived = stableCoinWBTC.balanceOf(user1);
        
        assertGt(sBTCReceived, 0);
        assertEq(stableCoin.balanceOf(user1), initialSETH - swapAmount);
        
        vm.stopPrank();
    }
    
    /* ==================== Edge Cases ==================== */
    
    function testExtremeExchangeRates() public {
        // Test with extreme price ratios
        ethPriceFeed.updatePrice(100e8); // Very low ETH price
        btcPriceFeed.updatePrice(100000e8); // Very high BTC price
        
        uint256 exchangeRate = dex.getExchangeRate();
        assertGt(exchangeRate, 1000e18); // Should be a very high ratio
        
        // Test swap still works
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL, 500e18); // Small mint
        dex.swapStableCoinForStableCoinWBTC(100e18);
        vm.stopPrank();
        
        assertGt(stableCoinWBTC.balanceOf(user1), 0);
    }
    
    function testZeroExchangeRateHandling() public {
        ethPriceFeed.updatePrice(1);
        btcPriceFeed.updatePrice(0);
        
        vm.expectRevert("Invalid price");
        dex.getExchangeRate();
    }
    
    /* ==================== Fuzz Tests ==================== */
    
    function testFuzzSwapAmount(uint256 swapAmount) public {
        vm.assume(swapAmount > 0);
        vm.assume(swapAmount <= 10000e18); // Reasonable upper bound
        
        // Setup user with enough tokens
        vm.startPrank(user1);
        dex.depositWETHCollateralAndMintStableCoin(ETH_COLLATERAL * 2, swapAmount * 2);
        
        uint256 initialBalance = stableCoin.balanceOf(user1);
        dex.swapStableCoinForStableCoinWBTC(swapAmount);
        
        assertEq(stableCoin.balanceOf(user1), initialBalance - swapAmount);
        assertGt(stableCoinWBTC.balanceOf(user1), 0);
        
        vm.stopPrank();
    }
    
    function testFuzzExchangeRate(uint256 ethPrice, uint256 btcPrice) public {
        vm.assume(ethPrice > 0 && ethPrice <= 10000e8);
        vm.assume(btcPrice > 0 && btcPrice <= 200000e8);
        vm.assume(btcPrice >= ethPrice); // BTC typically worth more than ETH
        
        ethPriceFeed.updatePrice(int256(ethPrice));
        btcPriceFeed.updatePrice(int256(btcPrice));
        
        uint256 expectedRate = (btcPrice * 1e18) / ethPrice;
        uint256 actualRate = dex.getExchangeRate();
        
        assertEq(actualRate, expectedRate);
    }
}