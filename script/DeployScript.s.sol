// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DEX} from "../src/DEX.sol";
import {StableCoin} from "../src/Stablecoin.sol";
import {StableCoinWBTC} from "../src/StablecoinWBTC.sol";
import {StableCoinEngine} from "../src/StableCoinEngine.sol";
import {stablecoinWBTCEngine} from "../src/StablecoinWBTCEngine.sol";

contract DeployDEXSepolia is Script {
    // Sepolia testnet addresses
    address constant SEPOLIA_WETH = 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
    address constant SEPOLIA_WBTC = 0x29f2D40B0605204364af54EC677bD022dA425d03; // Mock WBTC on Sepolia
    address constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant SEPOLIA_BTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    function run() external {
        // Verify we're on Sepolia
        require(block.chainid == 11155111, "This script is only for Sepolia testnet (chainid: 11155111)");
        
        console.log("=== Deploying DEX System to Sepolia Testnet ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("");

        vm.startBroadcast();

        // Deploy the contracts
        (
            address stableCoinAddress,
            address stableCoinWBTCAddress,
            address stableCoinEngineAddress,
            address stablecoinWBTCEngineAddress,
            address dexAddress
        ) = deployContracts();

        vm.stopBroadcast();

        // Log deployment details
        logDeploymentDetails(
            stableCoinAddress,
            stableCoinWBTCAddress,
            stableCoinEngineAddress,
            stablecoinWBTCEngineAddress,
            dexAddress
        );

        // Save deployment addresses to file
        saveDeploymentInfo(
            stableCoinAddress,
            stableCoinWBTCAddress,
            stableCoinEngineAddress,
            stablecoinWBTCEngineAddress,
            dexAddress
        );
    }

    function deployContracts() internal returns (
        address stableCoinAddress,
        address stableCoinWBTCAddress,
        address stableCoinEngineAddress,
        address stablecoinWBTCEngineAddress,
        address dexAddress
    ) {
        // Step 1: Deploy StableCoin tokens
        console.log("1. Deploying StableCoin (STC)...");
        StableCoin stableCoin = new StableCoin();
        stableCoinAddress = address(stableCoin);
        console.log(" StableCoin deployed at:", stableCoinAddress);

        console.log("2. Deploying StableCoinWBTC (SWBTC)...");
        StableCoinWBTC stableCoinWBTC = new StableCoinWBTC();
        stableCoinWBTCAddress = address(stableCoinWBTC);
        console.log("StableCoinWBTC deployed at:", stableCoinWBTCAddress);

        // Step 2: Deploy Engine contracts
        console.log("3. Deploying StableCoinEngine...");
        StableCoinEngine stableCoinEngine = new StableCoinEngine(
            stableCoinAddress,
            SEPOLIA_WETH,
            SEPOLIA_ETH_USD_PRICE_FEED
        );
        stableCoinEngineAddress = address(stableCoinEngine);
        console.log("StableCoinEngine deployed at:", stableCoinEngineAddress);

        console.log("4. Deploying stablecoinWBTCEngine...");
        stablecoinWBTCEngine stablecoinWBTCEngineContract = new stablecoinWBTCEngine(
            stableCoinWBTCAddress,
            SEPOLIA_WBTC,
            SEPOLIA_BTC_USD_PRICE_FEED
        );
        stablecoinWBTCEngineAddress = address(stablecoinWBTCEngineContract);
        console.log("stablecoinWBTCEngine deployed at:", stablecoinWBTCEngineAddress);

        // Step 3: Deploy DEX contract
        console.log("5. Deploying DEX...");
        DEX dex = new DEX(
            stablecoinWBTCEngineAddress,
            stableCoinEngineAddress
        );
        dexAddress = address(dex);
        console.log("DEX deployed at:", dexAddress);

        console.log("");
        console.log("All contracts deployed successfully!");

        return (
            stableCoinAddress,
            stableCoinWBTCAddress,
            stableCoinEngineAddress,
            stablecoinWBTCEngineAddress,
            dexAddress
        );
    }

    function logDeploymentDetails(
        address stableCoinAddress,
        address stableCoinWBTCAddress,
        address stableCoinEngineAddress,
        address stablecoinWBTCEngineAddress,
        address dexAddress
    ) internal view {
        console.log("");
        console.log("=== SEPOLIA DEPLOYMENT SUMMARY ===");
        console.log("Deployer:", msg.sender);
        console.log("Block Number:", block.number);
        console.log("");
        console.log("Deployed Contracts:");
        console.log("StableCoin (STC):", stableCoinAddress);
        console.log(" StableCoinWBTC (SWBTC):", stableCoinWBTCAddress);
        console.log(" StableCoinEngine:", stableCoinEngineAddress);
        console.log(" stablecoinWBTCEngine:", stablecoinWBTCEngineAddress);
        console.log(" DEX:", dexAddress);
        console.log("");
        console.log(" Sepolia Network Dependencies:");
        console.log("WETH:", SEPOLIA_WETH);
        console.log(" WBTC (Mock):", SEPOLIA_WBTC);
        console.log("ETH/USD Price Feed:", SEPOLIA_ETH_USD_PRICE_FEED);
        console.log(" BTC/USD Price Feed:", SEPOLIA_BTC_USD_PRICE_FEED);
        console.log("");
        console.log("Etherscan Links:");
        console.log(" StableCoin: https://sepolia.etherscan.io/address/", stableCoinAddress);
        console.log(" StableCoinWBTC: https://sepolia.etherscan.io/address/", stableCoinWBTCAddress);
        console.log(" StableCoinEngine: https://sepolia.etherscan.io/address/", stableCoinEngineAddress);
        console.log(" stablecoinWBTCEngine: https://sepolia.etherscan.io/address/", stablecoinWBTCEngineAddress);
        console.log(" DEX: https://sepolia.etherscan.io/address/", dexAddress);
        console.log("");
    }

    function saveDeploymentInfo(
        address stableCoinAddress,
        address stableCoinWBTCAddress,
        address stableCoinEngineAddress,
        address stablecoinWBTCEngineAddress,
        address dexAddress
    ) internal {
        string memory deploymentInfo = string(
            abi.encodePacked(
                "# DEX Sepolia Testnet Deployment\n\n",
                "**Deployment Date:** ", vm.toString(block.timestamp), "\n",
                "**Deployer:** ", vm.toString(msg.sender), "\n",
                "**Block Number:** ", vm.toString(block.number), "\n",
                "**Chain ID:** 11155111 (Sepolia)\n\n",
                "##Deployed Contracts\n\n",
                "| Contract | Address | Etherscan Link |\n",
                "|----------|---------|----------------|\n",
                "| StableCoin (STC) | `", vm.toString(stableCoinAddress), "` | [View](https://sepolia.etherscan.io/address/", vm.toString(stableCoinAddress), ") |\n",
                "| StableCoinWBTC (SWBTC) | `", vm.toString(stableCoinWBTCAddress), "` | [View](https://sepolia.etherscan.io/address/", vm.toString(stableCoinWBTCAddress), ") |\n",
                "| StableCoinEngine | `", vm.toString(stableCoinEngineAddress), "` | [View](https://sepolia.etherscan.io/address/", vm.toString(stableCoinEngineAddress), ") |\n",
                "| stablecoinWBTCEngine | `", vm.toString(stablecoinWBTCEngineAddress), "` | [View](https://sepolia.etherscan.io/address/", vm.toString(stablecoinWBTCEngineAddress), ") |\n",
                "| DEX | `", vm.toString(dexAddress), "` | [View](https://sepolia.etherscan.io/address/", vm.toString(dexAddress), ") |\n\n",
                "##Sepolia Dependencies\n\n",
                "| Asset | Address |\n",
                "|-------|----------|\n",
                "| WETH | `", vm.toString(SEPOLIA_WETH), "` |\n",
                "| WBTC (Mock) | `", vm.toString(SEPOLIA_WBTC), "` |\n",
                "| ETH/USD Price Feed | `", vm.toString(SEPOLIA_ETH_USD_PRICE_FEED), "` |\n",
                "| BTC/USD Price Feed | `", vm.toString(SEPOLIA_BTC_USD_PRICE_FEED), "` |\n\n",
                "## Next Steps\n\n",
                "1. Verify contracts on Etherscan\n",
                "2. Test the system functionality\n",
                "3. Set up monitoring and alerts\n",
                "4. Document the API endpoints\n"
            )
        );

        string memory fileName = string(
            abi.encodePacked(
                "sepolia-deployment-",
                vm.toString(block.timestamp),
                ".md"
            )
        );

        vm.writeFile(fileName, deploymentInfo);
        console.log("Deployment info saved to:", fileName);
    }

    // Verification function to test deployment
    function verifyDeployment(address dexAddress) external view {
        require(dexAddress != address(0), "DEX not deployed");
        require(block.chainid == 11155111, "Not on Sepolia testnet");
        
        DEX dex = DEX(dexAddress);
        
        console.log("=== SEPOLIA DEPLOYMENT VERIFICATION ===");
        console.log("DEX Address:", dexAddress);
        console.log("StableCoinEngine:", address(dex.stableCoinEngineContract()));
        console.log("stablecoinWBTCEngine:", address(dex.stablecoinWBTCEngineContract()));
        console.log("Total Liquidity WETH:", dex.totalLiquidityWETH());
        console.log("Total Liquidity WBTC:", dex.totalLiquidityWBTC());
        console.log("Verification complete!");
    }

    // Helper function to get Sepolia config
    function getSepoliaConfig() external pure returns (
        address weth,
        address wbtc,
        address ethUsdPriceFeed,
        address btcUsdPriceFeed
    ) {
        return (
            SEPOLIA_WETH,
            SEPOLIA_WBTC,
            SEPOLIA_ETH_USD_PRICE_FEED,
            SEPOLIA_BTC_USD_PRICE_FEED
        );
    }
}