// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "src/Stablecoin.sol";
import "src/StablecoinWBTC.sol";
import "src/StableCoinEngine.sol";
import "src/StablecoinWBTCEngine.sol";
import "src/DEX.sol";

contract DeployScript is Script {
    // Sepolia testnet addresses
    address constant WETH_SEPOLIA = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant WBTC_SEPOLIA = 0x29f2D40B0605204364af54EC677bD022dA425d03; // Mock WBTC for testing
    
    // Chainlink Price Feed addresses for Sepolia
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant BTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Starting deployment on Sepolia testnet...");
        console.log("Deployer address:", vm.addr(deployerPrivateKey));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy StableCoin tokens
        console.log("\n=== Deploying StableCoin Tokens ===");
        StableCoin stableCoin = new StableCoin();
        console.log("StableCoin (sETH) deployed at:", address(stableCoin));
        
        StableCoinWBTC stableCoinWBTC = new StableCoinWBTC();
        console.log("StableCoinWBTC (sBTC) deployed at:", address(stableCoinWBTC));
        
        // Step 2: Deploy Engines
        console.log("\n=== Deploying Engines ===");
        StableCoinEngine stableCoinEngine = new StableCoinEngine(
            address(stableCoin),
            WETH_SEPOLIA,
            ETH_USD_PRICE_FEED
        );
        console.log("StableCoinEngine deployed at:", address(stableCoinEngine));
        
        stablecoinWBTCEngine stablecoinWBTCEngineContract = new stablecoinWBTCEngine(
            address(stableCoinWBTC),
            WBTC_SEPOLIA,
            BTC_USD_PRICE_FEED
        );
        console.log("stablecoinWBTCEngine deployed at:", address(stablecoinWBTCEngineContract));
        
        // Step 3: Deploy DEX
        console.log("\n=== Deploying DEX ===");
        DEX dex = new DEX(
            address(stablecoinWBTCEngineContract),
            address(stableCoinEngine),
            address(stableCoin),
            address(stableCoinWBTC)
        );
        console.log("DEX deployed at:", address(dex));
        
        vm.stopBroadcast();
        
        // Log all deployed addresses for easy reference
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Sepolia Testnet");
        console.log("StableCoin (sETH):", address(stableCoin));
        console.log("StableCoinWBTC (sBTC):", address(stableCoinWBTC));
        console.log("StableCoinEngine:", address(stableCoinEngine));
        console.log("stablecoinWBTCEngine:", address(stablecoinWBTCEngineContract));
        console.log("DEX:", address(dex));
        
        console.log("\n=== External Dependencies ===");
        console.log("WETH Sepolia:", WETH_SEPOLIA);
        console.log("WBTC Sepolia:", WBTC_SEPOLIA);
        console.log("ETH/USD Price Feed:", ETH_USD_PRICE_FEED);
        console.log("BTC/USD Price Feed:", BTC_USD_PRICE_FEED);
        
        // Verify deployment by checking some basic properties
        console.log("\n=== Verification ===");
        console.log("StableCoin name:", stableCoin.name());
        console.log("StableCoin symbol:", stableCoin.symbol());
        console.log("StableCoinWBTC name:", stableCoinWBTC.name());
        console.log("StableCoinWBTC symbol:", stableCoinWBTC.symbol());
        
        // Test price feeds
        try stableCoinEngine.getLatestPrice() returns (uint256 ethPrice) {
            console.log("ETH Price from feed:", ethPrice);
        } catch {
            console.log("Warning: Could not fetch ETH price");
        }
        
        try stablecoinWBTCEngineContract.getLatestPrice() returns (uint256 btcPrice) {
            console.log("BTC Price from feed:", btcPrice);
        } catch {
            console.log("Warning: Could not fetch BTC price");
        }
        
        console.log("\nDeployment completed successfully!");
    }
}

// Alternative simplified deployment script if you prefer manual steps
contract SimpleDeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy tokens
        StableCoin stableCoin = new StableCoin();
        StableCoinWBTC stableCoinWBTC = new StableCoinWBTC();
        
        // Deploy engines with Sepolia addresses
        StableCoinEngine stableCoinEngine = new StableCoinEngine(
            address(stableCoin),
            0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14, // WETH
            0x694AA1769357215DE4FAC081bf1f309aDC325306  // ETH/USD
        );
        
        stablecoinWBTCEngine stablecoinWBTCEngineContract = new stablecoinWBTCEngine(
            address(stableCoinWBTC),
            0x29f2D40B0605204364af54EC677bD022dA425d03, // WBTC
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43  // BTC/USD
        );
        
        // Deploy DEX
        DEX dex = new DEX(
            address(stablecoinWBTCEngineContract),
            address(stableCoinEngine),
            address(stableCoin),
            address(stableCoinWBTC)
        );
        
        vm.stopBroadcast();
        
        console.log("StableCoin:", address(stableCoin));
        console.log("StableCoinWBTC:", address(stableCoinWBTC));
        console.log("StableCoinEngine:", address(stableCoinEngine));
        console.log("stablecoinWBTCEngine:", address(stablecoinWBTCEngineContract));
        console.log("DEX:", address(dex));
    }
}