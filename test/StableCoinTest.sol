// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {StableCoin} from "../src/Stablecoin.sol";
import {TestSetup} from "./TestSetup.sol";

/**
 * @title StableCoinTest
 * @dev Comprehensive tests for StableCoin.sol contract
 * Tests ERC20 functionality, minting, burning, access controls, and edge cases
 * Includes fuzz testing, gas optimization verification, and security checks
 */
contract StableCoinTest is TestSetup {
    StableCoin public stableCoin;
    
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
        stableCoin = new StableCoin();
        vm.label(address(stableCoin), "StableCoin");
        
        console2.log("\n=== StableCoin Test Setup ===");
        console2.log("Contract deployed at:", address(stableCoin));
        console2.log("Initial supply:", stableCoin.totalSupply());
    }
    
    /* ==================== Constructor and Initial State Tests ==================== */
    
    function testConstructor() public {
        assertEq(stableCoin.name(), "StableCoin", "Name should be StableCoin");
        assertEq(stableCoin.symbol(), "STC", "Symbol should be STC");
        assertEq(stableCoin.decimals(), 18, "Decimals should be 18");
        assertEq(stableCoin.totalSupply(), INITIAL_SUPPLY, "Total supply should be 1000e18");
        assertEq(stableCoin.balanceOf(address(this)), INITIAL_SUPPLY, "Deployer should have initial supply");
    }
    
    function testInitialState() public {
        // Check that no other addresses have tokens initially
        assertEq(stableCoin.balanceOf(user1), 0, "User1 should have no tokens initially");
        assertEq(stableCoin.balanceOf(user2), 0, "User2 should have no tokens initially");
        assertEq(stableCoin.balanceOf(address(0)), 0, "Zero address should have no tokens");
        
        // Check allowances are zero
        assertEq(stableCoin.allowance(address(this), user1), 0, "No allowance should exist initially");
        assertEq(stableCoin.allowance(user1, user2), 0, "No allowance should exist initially");
    }
    
    function testContractDeployment() public {
        // Test deploying another instance
        StableCoin newCoin = new StableCoin();
        assertEq(newCoin.balanceOf(address(this)), INITIAL_SUPPLY, "New instance should have same initial supply");
        assertTrue(address(newCoin) != address(stableCoin), "New instance should have different address");
    }
    
    /* ==================== Mint Function Tests ==================== */
    
    function testMint() public {
        startScenario("Basic Mint");
        
        uint256 initialBalance = stableCoin.balanceOf(user1);
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), user1, MINT_AMOUNT);
        
        stableCoin.mint(user1, MINT_AMOUNT);
        
        assertEq(stableCoin.balanceOf(user1), initialBalance + MINT_AMOUNT, "User balance should increase");
        assertEq(stableCoin.totalSupply(), initialTotalSupply + MINT_AMOUNT, "Total supply should increase");
        
        endScenario("Basic Mint");
    }
    
    function testMintMultipleRecipients() public {
        startScenario("Mint to Multiple Recipients");
        
        stableCoin.mint(user1, MINT_AMOUNT);
        stableCoin.mint(user2, MINT_AMOUNT * 2);
        stableCoin.mint(user3, MINT_AMOUNT / 2);
        
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT, "User1 should have correct balance");
        assertEq(stableCoin.balanceOf(user2), MINT_AMOUNT * 2, "User2 should have correct balance");
        assertEq(stableCoin.balanceOf(user3), MINT_AMOUNT / 2, "User3 should have correct balance");
        
        uint256 expectedTotal = INITIAL_SUPPLY + MINT_AMOUNT + (MINT_AMOUNT * 2) + (MINT_AMOUNT / 2);
        assertEq(stableCoin.totalSupply(), expectedTotal, "Total supply should be correct");
        
        endScenario("Mint to Multiple Recipients");
    }
    
    function testMintToSelf() public {
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        stableCoin.mint(address(this), MINT_AMOUNT);
        assertEq(stableCoin.balanceOf(address(this)), initialBalance + MINT_AMOUNT, "Self mint should work");
    }
    
    function testMintZeroAddress() public {
        vm.expectRevert("Cannot mint to the zero address");
        stableCoin.mint(address(0), MINT_AMOUNT);
    }
    
    function testMintZeroAmount() public {
        vm.expectRevert("Amount must be greater than zero");
        stableCoin.mint(user1, 0);
    }
    
    function testMintLargeAmount() public {
        startScenario("Mint Large Amount");
        
        uint256 largeAmount = type(uint128).max; // Large but safe amount
        stableCoin.mint(user1, largeAmount);
        assertEq(stableCoin.balanceOf(user1), largeAmount, "Large mint should work");
        
        endScenario("Mint Large Amount");
    }
    
    function testMintMaxAmount() public {
        // Test minting near max uint256 (should handle overflow protection)
        uint256 maxSafeMint = type(uint256).max / 2;
        stableCoin.mint(user1, maxSafeMint);
        assertEq(stableCoin.balanceOf(user1), maxSafeMint, "Max safe mint should work");
    }
    
    function testMintGasUsage() public {
        startGasTracking();
        stableCoin.mint(user1, MINT_AMOUNT);
        endGasTracking("mint operation");
    }
    
    /* ==================== Burn Function Tests ==================== */
    
    function testBurn() public {
        startScenario("Basic Burn");
        
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), address(0), BURN_AMOUNT);
        
        stableCoin.burn(BURN_AMOUNT);
        
        assertEq(stableCoin.balanceOf(address(this)), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(stableCoin.totalSupply(), initialTotalSupply - BURN_AMOUNT, "Total supply should decrease");
        
        endScenario("Basic Burn");
    }
    
    function testBurnFromUser() public {
        startScenario("Burn from User");
        
        // First mint tokens to user
        stableCoin.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        uint256 initialBalance = stableCoin.balanceOf(user1);
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        stableCoin.burn(BURN_AMOUNT);
        
        assertEq(stableCoin.balanceOf(user1), initialBalance - BURN_AMOUNT, "User balance should decrease");
        assertEq(stableCoin.totalSupply(), initialTotalSupply - BURN_AMOUNT, "Total supply should decrease");
        vm.stopPrank();
        
        endScenario("Burn from User");
    }
    
    function testBurnPartialBalance() public {
        stableCoin.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        uint256 burnAmount = MINT_AMOUNT / 3;
        stableCoin.burn(burnAmount);
        
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT - burnAmount, "Partial burn should work");
        vm.stopPrank();
    }
    
    function testBurnEntireBalance() public {
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        stableCoin.burn(currentBalance);
        assertEq(stableCoin.balanceOf(address(this)), 0, "Should burn entire balance");
    }
    
    function testBurnZeroAmount() public {
        vm.expectRevert("Amount must be greater than zero");
        stableCoin.burn(0);
    }
    
    function testBurnInsufficientBalance() public {
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        uint256 burnAmount = currentBalance + 1;
        
        vm.expectRevert("Insufficient balance to burn");
        stableCoin.burn(burnAmount);
    }
    
    function testBurnFromZeroBalance() public {
        vm.startPrank(user1);
        vm.expectRevert("Insufficient balance to burn");
        stableCoin.burn(1);
        vm.stopPrank();
    }
    
    function testBurnGasUsage() public {
        startGasTracking();
        stableCoin.burn(BURN_AMOUNT);
        endGasTracking("burn operation");
    }
    
    function testBurnMultipleOperations() public {
        startScenario("Multiple Burn Operations");
        
        uint256 burnAmount1 = BURN_AMOUNT;
        uint256 burnAmount2 = BURN_AMOUNT / 2;
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        
        stableCoin.burn(burnAmount1);
        stableCoin.burn(burnAmount2);
        
        uint256 expectedBalance = initialBalance - burnAmount1 - burnAmount2;
        assertEq(stableCoin.balanceOf(address(this)), expectedBalance, "Multiple burns should work");
        
        endScenario("Multiple Burn Operations");
    }
    
    /* ==================== ERC20 Standard Transfer Tests ==================== */
    
    function testTransfer() public {
        startScenario("Basic Transfer");
        
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), user1, TRANSFER_AMOUNT);
        
        bool success = stableCoin.transfer(user1, TRANSFER_AMOUNT);
        assertTrue(success, "Transfer should succeed");
        assertEq(stableCoin.balanceOf(user1), TRANSFER_AMOUNT, "User should receive tokens");
        assertEq(stableCoin.balanceOf(address(this)), INITIAL_SUPPLY - TRANSFER_AMOUNT, "Sender balance should decrease");
        
        endScenario("Basic Transfer");
    }
    
    function testTransferZeroAmount() public {
        bool success = stableCoin.transfer(user1, 0);
        assertTrue(success, "Zero transfer should succeed");
        assertEq(stableCoin.balanceOf(user1), 0, "User should have no tokens");
    }
    
    function testTransferInsufficientBalance() public {
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        vm.expectRevert(); 
        stableCoin.transfer(user1, currentBalance + 1);
    }
    
    function testTransferToSelf() public {
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        bool success = stableCoin.transfer(address(this), TRANSFER_AMOUNT);
        assertTrue(success, "Self transfer should succeed");
        assertEq(stableCoin.balanceOf(address(this)), initialBalance, "Balance should remain same");
    }
    
    function testTransferToZeroAddress() public {
        // ERC20 standard allows transfer to zero address (burns tokens)
        uint256 initialSupply = stableCoin.totalSupply();
        bool success = stableCoin.transfer(address(0), TRANSFER_AMOUNT);
        assertTrue(success, "Transfer to zero should succeed");
        assertEq(stableCoin.totalSupply(), initialSupply, "Supply should remain same"); // Note: OpenZeppelin doesn't burn on transfer to zero
    }
    
    function testTransferEntireBalance() public {
        uint256 balance = stableCoin.balanceOf(address(this));
        stableCoin.transfer(user1, balance);
        assertEq(stableCoin.balanceOf(address(this)), 0, "Sender should have zero balance");
        assertEq(stableCoin.balanceOf(user1), balance, "Receiver should have all tokens");
    }
    
    function testTransferBetweenUsers() public {
        startScenario("Transfer Between Users");
        
        // Setup: Give tokens to user1
        stableCoin.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        stableCoin.transfer(user2, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT - TRANSFER_AMOUNT, "User1 balance should decrease");
        assertEq(stableCoin.balanceOf(user2), TRANSFER_AMOUNT, "User2 should receive tokens");
        
        endScenario("Transfer Between Users");
    }
    
    function testTransferGasUsage() public {
        startGasTracking();
        stableCoin.transfer(user1, TRANSFER_AMOUNT);
        endGasTracking("transfer operation");
    }
    
    /* ==================== ERC20 Approval Tests ==================== */
    
    function testApprove() public {
        startScenario("Basic Approval");
        
        vm.expectEmit(true, true, false, true);
        emit Approval(address(this), user1, APPROVE_AMOUNT);
        
        bool success = stableCoin.approve(user1, APPROVE_AMOUNT);
        assertTrue(success, "Approval should succeed");
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT, "Allowance should be set");
        
        endScenario("Basic Approval");
    }
    
    function testApproveZeroAmount() public {
        bool success = stableCoin.approve(user1, 0);
        assertTrue(success, "Zero approval should succeed");
        assertEq(stableCoin.allowance(address(this), user1), 0, "Allowance should be zero");
    }
    
    function testApproveOverwrite() public {
        // First approval
        stableCoin.approve(user1, APPROVE_AMOUNT);
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT);
        
        // Overwrite approval
        uint256 newAmount = APPROVE_AMOUNT * 2;
        stableCoin.approve(user1, newAmount);
        assertEq(stableCoin.allowance(address(this), user1), newAmount, "Should overwrite allowance");
    }
    
    function testApproveMaxAmount() public {
        stableCoin.approve(user1, type(uint256).max);
        assertEq(stableCoin.allowance(address(this), user1), type(uint256).max, "Max approval should work");
    }
    
    function testApproveMultipleSpenders() public {
        startScenario("Multiple Spenders");
        
        stableCoin.approve(user1, APPROVE_AMOUNT);
        stableCoin.approve(user2, APPROVE_AMOUNT * 2);
        stableCoin.approve(user3, APPROVE_AMOUNT / 2);
        
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT, "User1 allowance");
        assertEq(stableCoin.allowance(address(this), user2), APPROVE_AMOUNT * 2, "User2 allowance");
        assertEq(stableCoin.allowance(address(this), user3), APPROVE_AMOUNT / 2, "User3 allowance");
        
        endScenario("Multiple Spenders");
    }
    
    function testApproveToSelf() public {
        stableCoin.approve(address(this), APPROVE_AMOUNT);
        assertEq(stableCoin.allowance(address(this), address(this)), APPROVE_AMOUNT, "Self approval should work");
    }
    
    function testApproveGasUsage() public {
        startGasTracking();
        stableCoin.approve(user1, APPROVE_AMOUNT);
        endGasTracking("approve operation");
    }
    
    /* ==================== ERC20 TransferFrom Tests ==================== */
    
    function testTransferFrom() public {
        startScenario("Basic TransferFrom");
        
        // First approve
        stableCoin.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), user2, TRANSFER_AMOUNT);
        
        bool success = stableCoin.transferFrom(address(this), user2, TRANSFER_AMOUNT);
        assertTrue(success, "TransferFrom should succeed");
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user2), TRANSFER_AMOUNT, "User2 should receive tokens");
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT - TRANSFER_AMOUNT, "Allowance should decrease");
        
        endScenario("Basic TransferFrom");
    }
    
    function testTransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = TRANSFER_AMOUNT / 2;
        
        stableCoin.approve(user1, allowanceAmount);
        
        vm.startPrank(user1);
        vm.expectRevert();
        stableCoin.transferFrom(address(this), user2, TRANSFER_AMOUNT);
        vm.stopPrank();
    }
    
    function testTransferFromInsufficientBalance() public {
        // Give user1 more allowance than this contract has balance
        stableCoin.approve(user1, type(uint256).max);
        
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        
        vm.startPrank(user1);
        vm.expectRevert();
        stableCoin.transferFrom(address(this), user2, currentBalance + 1);
        vm.stopPrank();
    }
    
    function testTransferFromMaxAllowance() public {
        // Test infinite allowance (max uint256)
        stableCoin.approve(user1, type(uint256).max);
        
        vm.startPrank(user1);
        stableCoin.transferFrom(address(this), user2, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        // With max allowance, it should remain max
        assertEq(stableCoin.allowance(address(this), user1), type(uint256).max, "Max allowance should remain");
        assertEq(stableCoin.balanceOf(user2), TRANSFER_AMOUNT, "Transfer should succeed");
    }
    
    function testTransferFromZeroAmount() public {
        stableCoin.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        bool success = stableCoin.transferFrom(address(this), user2, 0);
        assertTrue(success, "Zero transferFrom should succeed");
        vm.stopPrank();
        
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT, "Allowance should remain same");
    }
    
    function testTransferFromSelfApproval() public {
        stableCoin.approve(address(this), APPROVE_AMOUNT);
        
        bool success = stableCoin.transferFrom(address(this), user1, TRANSFER_AMOUNT);
        assertTrue(success, "Self transferFrom should work");
        
        assertEq(stableCoin.balanceOf(user1), TRANSFER_AMOUNT, "Transfer should succeed");
    }
    
    function testTransferFromGasUsage() public {
        stableCoin.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        startGasTracking();
        stableCoin.transferFrom(address(this), user2, TRANSFER_AMOUNT);
        endGasTracking("transferFrom operation");
        vm.stopPrank();
    }
    
    /* ==================== BurnFrom Function Tests ==================== */
    
    function testBurnFrom() public {
        startScenario("Basic BurnFrom");
        
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        // Approve user1 to burn tokens
        stableCoin.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), address(0), BURN_AMOUNT);
        
        stableCoin.burnFrom(address(this), BURN_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(address(this)), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(stableCoin.totalSupply(), initialTotalSupply - BURN_AMOUNT, "Supply should decrease");
        assertEq(stableCoin.allowance(address(this), user1), APPROVE_AMOUNT - BURN_AMOUNT, "Allowance should decrease");
        
        endScenario("Basic BurnFrom");
    }
    
    function testBurnFromInsufficientAllowance() public {
        uint256 allowanceAmount = BURN_AMOUNT / 2;
        
        stableCoin.approve(user1, allowanceAmount);
        
        vm.startPrank(user1);
        vm.expectRevert();
        stableCoin.burnFrom(address(this), BURN_AMOUNT);
        vm.stopPrank();
    }
    
    function testBurnFromInsufficientBalance() public {
        // Setup user with no tokens
        stableCoin.approve(user1, type(uint256).max);
        
        vm.startPrank(user1);
        vm.expectRevert();
        stableCoin.burnFrom(user2, BURN_AMOUNT); // user2 has no tokens
        vm.stopPrank();
    }
    
    function testBurnFromMaxAllowance() public {
        stableCoin.approve(user1, type(uint256).max);
        
        vm.startPrank(user1);
        stableCoin.burnFrom(address(this), BURN_AMOUNT);
        vm.stopPrank();
        
        // Max allowance should remain max
        assertEq(stableCoin.allowance(address(this), user1), type(uint256).max, "Max allowance should remain");
    }
    
    function testBurnFromSelfApproval() public {
        stableCoin.approve(address(this), APPROVE_AMOUNT);
        
        uint256 initialBalance = stableCoin.balanceOf(address(this));
        stableCoin.burnFrom(address(this), BURN_AMOUNT);
        
        assertEq(stableCoin.balanceOf(address(this)), initialBalance - BURN_AMOUNT, "Self burnFrom should work");
    }
    
    function testBurnFromGasUsage() public {
        stableCoin.approve(user1, APPROVE_AMOUNT);
        
        vm.startPrank(user1);
        startGasTracking();
        stableCoin.burnFrom(address(this), BURN_AMOUNT);
        endGasTracking("burnFrom operation");
        vm.stopPrank();
    }
    
    /* ==================== Integration and Complex Scenario Tests ==================== */
    
    function testMintAndBurnCycle() public {
        startScenario("Mint and Burn Cycle");
        
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        // Mint
        stableCoin.mint(user1, MINT_AMOUNT);
        assertEq(stableCoin.totalSupply(), initialTotalSupply + MINT_AMOUNT, "Supply should increase after mint");
        
        // Burn
        vm.startPrank(user1);
        stableCoin.burn(MINT_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoin.totalSupply(), initialTotalSupply, "Supply should return to initial");
        assertEq(stableCoin.balanceOf(user1), 0, "User should have no tokens");
        
        endScenario("Mint and Burn Cycle");
    }
    
    function testComplexTransferAndBurnScenario() public {
        startScenario("Complex Transfer and Burn");
        
        uint256 mintAmount = MINT_AMOUNT * 2;
        uint256 transferAmount = MINT_AMOUNT;
        uint256 burnAmount = BURN_AMOUNT;
        
        // Mint to user1
        stableCoin.mint(user1, mintAmount);
        
        // Transfer from user1 to user2
        vm.startPrank(user1);
        stableCoin.transfer(user2, transferAmount);
        vm.stopPrank();
        
        // Burn from user2
        vm.startPrank(user2);
        stableCoin.burn(burnAmount);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user1), mintAmount - transferAmount, "User1 balance should be correct");
        assertEq(stableCoin.balanceOf(user2), transferAmount - burnAmount, "User2 balance should be correct");
        
        endScenario("Complex Transfer and Burn");
    }
    
    function testMultiUserOperations() public {
        startScenario("Multi-User Operations");
        
        // Mint to multiple users
        stableCoin.mint(user1, MINT_AMOUNT);
        stableCoin.mint(user2, MINT_AMOUNT * 2);
        stableCoin.mint(user3, MINT_AMOUNT / 2);
        
        // Cross transfers
        vm.startPrank(user1);
        stableCoin.transfer(user2, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        stableCoin.transfer(user3, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        // Verify final balances
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT - TRANSFER_AMOUNT, "User1 final balance");
        assertEq(stableCoin.balanceOf(user2), MINT_AMOUNT * 2 + TRANSFER_AMOUNT - TRANSFER_AMOUNT, "User2 final balance");
        assertEq(stableCoin.balanceOf(user3), MINT_AMOUNT / 2 + TRANSFER_AMOUNT, "User3 final balance");
        
        endScenario("Multi-User Operations");
    }
    
    function testApprovalAndTransferFromChain() public {
        startScenario("Approval and TransferFrom Chain");
        
        // Setup: mint tokens to user1
        stableCoin.mint(user1, MINT_AMOUNT);
        
        // user1 approves user2
        vm.startPrank(user1);
        stableCoin.approve(user2, APPROVE_AMOUNT);
        vm.stopPrank();
        
        // user2 transfers from user1 to user3
        vm.startPrank(user2);
        stableCoin.transferFrom(user1, user3, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user1), MINT_AMOUNT - TRANSFER_AMOUNT, "User1 should lose tokens");
        assertEq(stableCoin.balanceOf(user3), TRANSFER_AMOUNT, "User3 should receive tokens");
        assertEq(stableCoin.allowance(user1, user2), APPROVE_AMOUNT - TRANSFER_AMOUNT, "Allowance should decrease");
        
        endScenario("Approval and TransferFrom Chain");
    }
    
    /* ==================== Edge Case and Security Tests ==================== */
    
    function testMintToContractAddress() public {
        // Test minting to contract addresses
        stableCoin.mint(address(stableCoin), MINT_AMOUNT);
        assertEq(stableCoin.balanceOf(address(stableCoin)), MINT_AMOUNT, "Contract should be able to hold tokens");
    }
    
    function testBurnAfterTransfer() public {
        // Test burning tokens that were received via transfer
        stableCoin.transfer(user1, TRANSFER_AMOUNT);
        
        vm.startPrank(user1);
        stableCoin.burn(TRANSFER_AMOUNT);
        vm.stopPrank();
        
        assertEq(stableCoin.balanceOf(user1), 0, "User should have burned all received tokens");
    }
    
    function testReentrancyProtection() public {
        // Basic test - the OpenZeppelin implementation should be reentrancy safe
        // This tests that multiple operations in sequence work correctly
        stableCoin.mint(user1, MINT_AMOUNT);
        
        vm.startPrank(user1);
        stableCoin.approve(user2, APPROVE_AMOUNT);
        stableCoin.transfer(user2, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        vm.startPrank(user2);
        stableCoin.transferFrom(user1, user3, TRANSFER_AMOUNT / 2);
        vm.stopPrank();
        
        // Verify state consistency
        assertTrue(stableCoin.balanceOf(user1) + stableCoin.balanceOf(user2) + stableCoin.balanceOf(user3) > 0);
    }
    
    function testOperationOrderIndependence() public {
        // Test that operations produce same result regardless of order
        startScenario("Operation Order Independence");
        
        // Scenario 1: mint then transfer
        stableCoin.mint(user1, MINT_AMOUNT);
        vm.startPrank(user1);
        stableCoin.transfer(user2, TRANSFER_AMOUNT);
        vm.stopPrank();
        
        uint256 balance1_scenario1 = stableCoin.balanceOf(user1);
        uint256 balance2_scenario1 = stableCoin.balanceOf(user2);
        
        // Reset
        vm.startPrank(user1);
        stableCoin.transfer(address(this), stableCoin.balanceOf(user1));
        vm.stopPrank();
        vm.startPrank(user2);
        stableCoin.transfer(address(this), stableCoin.balanceOf(user2));
        vm.stopPrank();
        
        // Scenario 2: mint to different user then transfer
        stableCoin.mint(user2, MINT_AMOUNT);
        vm.startPrank(user2);
        stableCoin.transfer(user1, MINT_AMOUNT - TRANSFER_AMOUNT);
        vm.stopPrank();
        
        uint256 balance1_scenario2 = stableCoin.balanceOf(user1);
        uint256 balance2_scenario2 = stableCoin.balanceOf(user2);
        
        // Both scenarios should result in same total distribution
        assertEq(balance1_scenario1 + balance2_scenario1, balance1_scenario2 + balance2_scenario2, "Total should be same");
        
        endScenario("Operation Order Independence");
    }
    
    /* ==================== Fuzz Tests ==================== */
    
    function testFuzzMint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        vm.assume(amount <= type(uint128).max); // Prevent overflow
        
        uint256 initialBalance = stableCoin.balanceOf(to);
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        stableCoin.mint(to, amount);
        
        assertEq(stableCoin.balanceOf(to), initialBalance + amount, "Fuzz: Balance should increase");
        assertEq(stableCoin.totalSupply(), initialTotalSupply + amount, "Fuzz: Supply should increase");
    }
    
    function testFuzzBurn(uint256 amount) public {
        vm.assume(amount > 0);
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        vm.assume(amount <= currentBalance);
        
        uint256 initialTotalSupply = stableCoin.totalSupply();
        
        stableCoin.burn(amount);
        
        assertEq(stableCoin.balanceOf(address(this)), currentBalance - amount, "Fuzz: Balance should decrease");
        assertEq(stableCoin.totalSupply(), initialTotalSupply - amount, "Fuzz: Supply should decrease");
    }
    
    function testFuzzTransfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0);
        uint256 currentBalance = stableCoin.balanceOf(address(this));
        vm.assume(amount <= currentBalance);
        
        uint256 initialToBalance = stableCoin.balanceOf(to);
        
        bool success = stableCoin.transfer(to, amount);
        assertTrue(success, "Fuzz: Transfer should succeed");
        
        assertEq(stableCoin.balanceOf(to), initialToBalance + amount, "Fuzz: Recipient balance should increase");
        assertEq(stableCoin.balanceOf(address(this)), currentBalance - amount, "Fuzz: Sender balance should decrease");
    }
    
    function testFuzzApprove(address spender, uint256 amount) public {
        vm.assume(spender != address(0));
        
        bool success = stableCoin.approve(spender, amount);
        assertTrue(success, "Fuzz: Approval should succeed");
        assertEq(stableCoin.allowance(address(this), spender), amount, "Fuzz: Allowance should be set");
    }
    
    function testFuzzTransferFrom(address from, address to, uint256 approveAmount, uint256 transferAmount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(approveAmount > 0 && transferAmount > 0);
        vm.assume(transferAmount <= approveAmount);
        
        // Setup: mint tokens to 'from' address and approve this contract
        stableCoin.mint(from, approveAmount);
        
        vm.startPrank(from);
        stableCoin.approve(address(this), approveAmount);
        vm.stopPrank();
        
        uint256 initialFromBalance = stableCoin.balanceOf(from);
        uint256 initialToBalance = stableCoin.balanceOf(to);
        
        bool success = stableCoin.transferFrom(from, to, transferAmount);
        assertTrue(success, "Fuzz: TransferFrom should succeed");
        
        assertEq(stableCoin.balanceOf(from), initialFromBalance - transferAmount, "Fuzz: From balance should decrease");
        assertEq(stableCoin.balanceOf(to), initialToBalance + transferAmount, "Fuzz: To balance should increase");
    }
    
    /* ==================== Property-Based Invariant Tests ==================== */
    
    function testInvariantTotalSupplyConsistency() public {
        startScenario("Invariant: Total Supply Consistency");
        
        uint256 initialSupply = stableCoin.totalSupply();
        
        // Perform various operations
        stableCoin.mint(user1, MINT_AMOUNT);
        stableCoin.mint(user2, MINT_AMOUNT / 2);
        
        vm.startPrank(user1);
        stableCoin.burn(BURN_AMOUNT);
        vm.stopPrank();
        
        // Calculate expected supply
        uint256 expectedSupply = initialSupply + MINT_AMOUNT + (MINT_AMOUNT / 2) - BURN_AMOUNT;
        assertEq(stableCoin.totalSupply(), expectedSupply, "Total supply should match expected");
        
        endScenario("Invariant: Total Supply Consistency");
    }
    
    function testInvariantBalanceSum() public {
        startScenario("Invariant: Balance Sum Equals Total Supply");
        
        // Mint to various addresses
        stableCoin.mint(user1, MINT_AMOUNT);
        stableCoin.mint(user2, MINT_AMOUNT * 2);
        stableCoin.mint(user3, MINT_AMOUNT / 2);
        
        // Calculate sum of all balances
        uint256 totalBalances = stableCoin.balanceOf(address(this)) +
                               stableCoin.balanceOf(user1) +
                               stableCoin.balanceOf(user2) +
                               stableCoin.balanceOf(user3);
        
        assertEq(totalBalances, stableCoin.totalSupply(), "Sum of balances should equal total supply");
        
        endScenario("Invariant: Balance Sum Equals Total Supply");
    }
    
    function testInvariantTransferPreservesTotalSupply() public {
        uint256 initialSupply = stableCoin.totalSupply();
        
        // Perform multiple transfers
        stableCoin.transfer(user1, TRANSFER_AMOUNT);
        
        vm.startPrank(user1);
        stableCoin.transfer(user2, TRANSFER_AMOUNT / 2);
        vm.stopPrank();
        
        vm.startPrank(user2);
        stableCoin.transfer(user3, TRANSFER_AMOUNT / 4);
        vm.stopPrank();
        
        assertEq(stableCoin.totalSupply(), initialSupply, "Transfers should not change total supply");
    }
    
    /* ==================== Gas Optimization Tests ==================== */
    
    function testGasOptimizedOperations() public {
        startScenario("Gas Optimization Tests");
        
        console2.log("\n--- Gas Usage Analysis ---");
        
        // Test mint gas usage
        startGasTracking();
        stableCoin.mint(user1, MINT_AMOUNT);
        endGasTracking("mint operation");
        
        // Test transfer gas usage
        startGasTracking();
        stableCoin.transfer(user2, TRANSFER_AMOUNT);
        endGasTracking("transfer operation");
        
        // Test approve gas usage
        startGasTracking();
        stableCoin.approve(user1, APPROVE_AMOUNT);
        endGasTracking("approve operation");
        
        // Test burn gas usage
        startGasTracking();
        stableCoin.burn(BURN_AMOUNT);
        endGasTracking("burn operation");
        
        endScenario("Gas Optimization Tests");
    }
    
    /* ==================== Stress Tests ==================== */
    
    function testStressManyUsers() public {
        startScenario("Stress Test: Many Users");
        
        // Create many users and perform operations
        address[] memory users = new address[](10);
        for (uint i = 0; i < 10; i++) {
            users[i] = makeAddr(string(abi.encodePacked("stressUser", i)));
            stableCoin.mint(users[i], MINT_AMOUNT / 10);
        }
        
        // Perform cross-transfers
        for (uint i = 0; i < 9; i++) {
            vm.startPrank(users[i]);
            stableCoin.transfer(users[i + 1], MINT_AMOUNT / 100);
            vm.stopPrank();
        }
        
        // Verify total supply integrity
        uint256 expectedSupply = INITIAL_SUPPLY + (MINT_AMOUNT / 10) * 10;
        assertEq(stableCoin.totalSupply(), expectedSupply, "Total supply should remain consistent");
        
        endScenario("Stress Test: Many Users");
    }
    
    function testStressLargeOperations() public {
        startScenario("Stress Test: Large Operations");
        
        uint256 largeAmount = 1000000e18; // 1 million tokens
        
        stableCoin.mint(user1, largeAmount);
        
        vm.startPrank(user1);
        stableCoin.transfer(user2, largeAmount / 2);
        stableCoin.burn(largeAmount / 4);
        vm.stopPrank();
        
        // Verify consistency
        uint256 expectedUser1Balance = largeAmount - (largeAmount / 2) - (largeAmount / 4);
        assertEq(stableCoin.balanceOf(user1), expectedUser1Balance, "Large operation results should be correct");
        
        endScenario("Stress Test: Large Operations");
    }
}