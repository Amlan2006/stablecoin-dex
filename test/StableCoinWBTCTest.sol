// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StableCoinWBTC} from "../src/StablecoinWBTC.sol";
import {TestSetup} from "./TestSetup.sol";

/**
 * @title StableCoinWBTCTest
 * @dev Comprehensive tests for StableCoinWBTC.sol contract
 * Tests ERC20 functionality, minting, burning, access controls, and edge cases
 * Similar to StableCoin but for the WBTC-backed stablecoin variant
 */
contract StableCoinWBTCTest is TestSetup {
    StableCoinWBTC public stableCoinWBTC;
    
    // Events from ERC20 and custom events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    // Test constants
    uint256 constant INITIAL_SUPPLY = 1000e18;
    uint256 constant MINT_AMOUNT = 100e18;
    uint256 constant BURN_AMOUNT = 50e18;
    uint256 constant TRANSFER_AMOUNT = 25e18;
    uint256 constant APPROVE_AMOUNT = 75e18;
    
    function setUp() public override {
        super.setUp();
        stableCoinWBTC = new StableCoinWBTC();
        vm.label(address(stableCoinWBTC), "StableCoinWBTC");
        
        console2.log("\n=== StableCoinWBTC Test Setup ===");
        console2.log("Contract deployed at:", address(stableCoinWBTC));
        console2.log("Initial supply:", stableCoinWBTC.totalSupply());
    }
    
    /* ==================== Constructor and Initial State Tests ==================== */
    
    function testConstructor() public {
        assertEq(stableCoinWBTC.name(), "StableCoinWBTC", "Name should be StableCoinWBTC");
        assertEq(stableCoinWBTC.symbol(), "SWBTC", "Symbol should be SWBTC");
        assertEq(stableCoinWBTC.decimals(), 18, "Decimals should be 18");
        assertEq(stableCoinWBTC.totalSupply(), INITIAL_SUPPLY, "Total supply should be 1000e18");
        assertEq(stableCoinWBTC.balanceOf(address(this)), INITIAL_SUPPLY, "Deployer should have initial supply");
    }
    
    function testInitialState() public {
        // Check that no other addresses have tokens initially
        assertEq(stableCoinWBTC.balanceOf(user1), 0, "User1 should have no tokens initially");
        assertEq(stableCoinWBTC.balanceOf(user2), 0, "User2 should have no tokens initially");
        assertEq(stableCoinWBTC.balanceOf(address(0)), 0, "Zero address should have no tokens");
        
        // Check allowances are zero
        assertEq(stableCoinWBTC.allowance(address(this), user1), 0, "No allowance should exist initially");
        assertEq(stableCoinWBTC.allowance(user1, user2), 0, "No allowance should exist initially");
    }
    
    /* ==================== Mint Function Tests ==================== */
    
    function testMint() public {
        startScenario("Basic Mint");
        
        uint256 initialBalance = stableCoinWBTC.balanceOf(user1);
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, MINT_AMOUNT);
        
        stableCoinWBTC.mint(user1, MINT_AMOUNT);
        
        assertEq(stableCoinWBTC.balanceOf(user1), initialBalance + MINT_AMOUNT, "User balance should increase");
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply + MINT_AMOUNT, "Total supply should increase");
        
        endScenario("Basic Mint");
    }
    
    function testMintZeroAddress() public {
        vm.expectRevert("Cannot mint to the zero address");
        stableCoinWBTC.mint(address(0), MINT_AMOUNT);
    }
    
    function testMintZeroAmount() public {
        vm.expectRevert("Amount must be greater than zero");
        stableCoinWBTC.mint(user1, 0);
    }
    
    /* ==================== Burn Function Tests ==================== */
    
    function testBurn() public {
        startScenario("Basic Burn");
        
        uint256 initialBalance = stableCoinWBTC.balanceOf(address(this));
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), address(0), BURN_AMOUNT);
        
        stableCoinWBTC.burn(BURN_AMOUNT);
        
        assertEq(stableCoinWBTC.balanceOf(address(this)), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply - BURN_AMOUNT, "Total supply should decrease");
        
        endScenario("Basic Burn");
    }
    
    function testBurnZeroAmount() public {
        vm.expectRevert("Amount must be greater than zero");
        stableCoinWBTC.burn(0);
    }
    
    function testBurnInsufficientBalance() public {
        uint256 currentBalance = stableCoinWBTC.balanceOf(address(this));
        uint256 burnAmount = currentBalance + 1;
        
        vm.expectRevert("Insufficient balance to burn");
        stableCoinWBTC.burn(burnAmount);
    }
    
    /* ==================== ERC20 Standard Tests ==================== */
    
    function testTransfer() public {
        startScenario("Basic Transfer");
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), user1, TRANSFER_AMOUNT);
        
        bool success = stableCoinWBTC.transfer(user1, TRANSFER_AMOUNT);
        assertTrue(success, "Transfer should succeed");
        assertEq(stableCoinWBTC.balanceOf(user1), TRANSFER_AMOUNT, "User should receive tokens");
        assertEq(stableCoinWBTC.balanceOf(address(this)), INITIAL_SUPPLY - TRANSFER_AMOUNT, "Sender balance should decrease");
        
        endScenario("Basic Transfer");
    }
    
    function testApprove() public {
        startScenario("Basic Approval");
        
        vm.expectEmit(true, true, false, true);
        emit Approval(address(this), user1, APPROVE_AMOUNT);
        
        bool success = stableCoinWBTC.approve(user1, APPROVE_AMOUNT);
        assertTrue(success, "Approval should succeed");
        assertEq(stableCoinWBTC.allowance(address(this), user1), APPROVE_AMOUNT, "Allowance should be set");
        
        endScenario("Basic Approval");
    }
    
    function testTransferFrom() public {
        startScenario("Basic TransferFrom");
        
        // First approve
        stableCoinWBTC.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), user2, TRANSFER_AMOUNT);
        
        bool success = stableCoinWBTC.transferFrom(address(this), user2, TRANSFER_AMOUNT);
        assertTrue(success, "TransferFrom should succeed");
        vm.stopPrank();
        
        assertEq(stableCoinWBTC.balanceOf(user2), TRANSFER_AMOUNT, "User2 should receive tokens");
        assertEq(stableCoinWBTC.allowance(address(this), user1), APPROVE_AMOUNT - TRANSFER_AMOUNT, "Allowance should decrease");
        
        endScenario("Basic TransferFrom");
    }
    
    function testBurnFrom() public {
        startScenario("Basic BurnFrom");
        
        uint256 initialBalance = stableCoinWBTC.balanceOf(address(this));
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        // Approve user1 to burn tokens
        stableCoinWBTC.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), address(0), BURN_AMOUNT);
        
        stableCoinWBTC.burnFrom(address(this), BURN_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoinWBTC.balanceOf(address(this)), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply - BURN_AMOUNT, "Supply should decrease");
        assertEq(stableCoinWBTC.allowance(address(this), user1), APPROVE_AMOUNT - BURN_AMOUNT, "Allowance should decrease");
        
        endScenario("Basic BurnFrom");
    }
    
    /* ==================== Integration Tests ==================== */
    
    function testMintAndBurnCycle() public {
        startScenario("Mint and Burn Cycle");
        
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        // Mint
        stableCoinWBTC.mint(user1, MINT_AMOUNT);
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply + MINT_AMOUNT, "Supply should increase after mint");
        
        // Burn
        vm.startPrank(user1);
        stableCoinWBTC.burn(MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply, "Supply should return to initial");
        assertEq(stableCoinWBTC.balanceOf(user1), 0, "User should have no tokens");
        
        endScenario("Mint and Burn Cycle");
    }
    
    /* ==================== Fuzz Tests ==================== */
    
    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max); // Prevent overflow
        
        uint256 initialBalance = stableCoinWBTC.balanceOf(to);
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        stableCoinWBTC.mint(to, amount);
        
        assertEq(stableCoinWBTC.balanceOf(to), initialBalance + amount, "Fuzz: Balance should increase");
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply + amount, "Fuzz: Supply should increase");
    }
    
    function testFuzzBurn(uint256 amount) public {
        vm.assume(amount > 0);
        uint256 currentBalance = stableCoinWBTC.balanceOf(address(this));
        vm.assume(amount <= currentBalance);
        
        uint256 initialTotalSupply = stableCoinWBTC.totalSupply();
        
        stableCoinWBTC.burn(amount);
        
        assertEq(stableCoinWBTC.balanceOf(address(this)), currentBalance - amount, "Fuzz: Balance should decrease");
        assertEq(stableCoinWBTC.totalSupply(), initialTotalSupply - amount, "Fuzz: Supply should decrease");
    }
    
    function testFuzzTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        uint256 currentBalance = stableCoinWBTC.balanceOf(address(this));
        vm.assume(amount <= currentBalance);
        
        uint256 initialToBalance = stableCoinWBTC.balanceOf(to);
        
        bool success = stableCoinWBTC.transfer(to, amount);
        assertTrue(success, "Fuzz: Transfer should succeed");
        
        assertEq(stableCoinWBTC.balanceOf(to), initialToBalance + amount, "Fuzz: Recipient balance should increase");
        assertEq(stableCoinWBTC.balanceOf(address(this)), currentBalance - amount, "Fuzz: Sender balance should decrease");
    }
    
    /* ==================== Invariant Tests ==================== */
    
    function testInvariantTotalSupplyConsistency() public {
        startScenario("Invariant: Total Supply Consistency");
        
        uint256 initialSupply = stableCoinWBTC.totalSupply();
        
        // Perform various operations
        stableCoinWBTC.mint(user1, MINT_AMOUNT);
        stableCoinWBTC.mint(user2, MINT_AMOUNT / 2);
        
        vm.startPrank(user1);
        stableCoinWBTC.burn(BURN_AMOUNT);
        vm.stopPrank();
        
        // Calculate expected supply
        uint256 expectedSupply = initialSupply + MINT_AMOUNT + (MINT_AMOUNT / 2) - BURN_AMOUNT;
        assertEq(stableCoinWBTC.totalSupply(), expectedSupply, "Total supply should match expected");
        
        endScenario("Invariant: Total Supply Consistency");
    }
}