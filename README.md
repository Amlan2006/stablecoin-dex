## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
== Logs ==
  Starting deployment on Sepolia testnet...
  Deployer address: 0x750Fc8e72A4b00da9A5C9b116487ABC28360023f
  
=== Deploying StableCoin Tokens ===
  StableCoin (sETH) deployed at: 0x6c6ad692489a89514bD4C8e9344a0Bc387c32438
  StableCoinWBTC (sBTC) deployed at: 0x513be19378C375466e29D6b4d001E995FBA8c2ce
  
=== Deploying Engines ===
  StableCoinEngine deployed at: 0x7B82B239448B30372337fC22cFA02e9E7F10E812
  stablecoinWBTCEngine deployed at: 0x41233B5b9fAc54512ea322668AC20107F89A7562
  
=== Deploying DEX ===
  DEX deployed at: 0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee
  
=== Deployment Summary ===
  Network: Sepolia Testnet
  StableCoin (sETH): 0x6c6ad692489a89514bD4C8e9344a0Bc387c32438
  StableCoinWBTC (sBTC): 0x513be19378C375466e29D6b4d001E995FBA8c2ce
  StableCoinEngine: 0x7B82B239448B30372337fC22cFA02e9E7F10E812
  stablecoinWBTCEngine: 0x41233B5b9fAc54512ea322668AC20107F89A7562
  DEX: 0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee
  
=== External Dependencies ===
  WETH Sepolia: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14
  WBTC Sepolia: 0x29f2D40B0605204364af54EC677bD022dA425d03
  ETH/USD Price Feed: 0x694AA1769357215DE4FAC081bf1f309aDC325306
  BTC/USD Price Feed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
  
=== Verification ===
  StableCoin name: StableCoin
  StableCoin symbol: STC
  StableCoinWBTC name: StableCoinWBTC
  StableCoinWBTC symbol: SWBTC
  ETH Price from feed: 434082773000
  BTC Price from feed: 10985806584730
  
Deployment completed successfully!

## Setting up 1 EVM.

==========================

Chain 11155111

Estimated gas price: 0.003145779 gwei

Estimated total gas used for script: 9695884

Estimated amount required: 0.000030501108273636 ETH

==========================

##### sepolia
✅  [Success] Hash: 0x075f990f29cc406be364971af06a41a28eeb3e01028d47f9a358cc972be6d86a
Contract Address: 0x513be19378C375466e29D6b4d001E995FBA8c2ce
Block: 9088647
Paid: 0.000002252466833916 ETH (1121293 gas * 0.002008812 gwei)


##### sepolia
✅  [Success] Hash: 0xb9e13946d8e985c5c35bc93ad307a752b29e9fec3b63af30e18539d446c43093
Contract Address: 0x7B82B239448B30372337fC22cFA02e9E7F10E812
Block: 9088647
Paid: 0.0000034826271441 ETH (1733675 gas * 0.002008812 gwei)


##### sepolia
✅  [Success] Hash: 0x427124715def6c9c62d4a379138bb015061e9be86bfc59c25f2690298873e3ef
Contract Address: 0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee
Block: 9088647
Paid: 0.00000360716344404 ETH (1795670 gas * 0.002008812 gwei)


##### sepolia
✅  [Success] Hash: 0x7c7af4443a1b2cbc4545809f925908dfe85550ace3cc8972148122c0e064060f
Contract Address: 0x6c6ad692489a89514bD4C8e9344a0Bc387c32438
Block: 9088647
Paid: 0.000002252322199452 ETH (1121221 gas * 0.002008812 gwei)


##### sepolia
✅  [Success] Hash: 0x1700d59ec7995504b9cd336b2a754e6ebe96a4711e992b9dac28eac44ed93358
Contract Address: 0x41233B5b9fAc54512ea322668AC20107F89A7562
Block: 9088647
Paid: 0.00000338789157018 ETH (1686515 gas * 0.002008812 gwei)

✅ Sequence #1 on sepolia | Total Paid: 0.000014982471191688 ETH (7458374 gas * avg 0.002008812 gwei)
                                                                                                                                                                

==========================

ONCHAIN EXECUTION COMPLETE & SUCCESSFUL.
##
Start verification for (5) contracts
Start verifying contract `0x6c6ad692489a89514bD4C8e9344a0Bc387c32438` deployed on sepolia
EVM version: cancun
Compiler version: 0.8.30
Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

Submitting verification for [StableCoin] "0x6c6ad692489a89514bD4C8e9344a0Bc387c32438".
Contract successfully verified
Start verifying contract `0x513be19378C375466e29D6b4d001E995FBA8c2ce` deployed on sepolia
EVM version: cancun
Compiler version: 0.8.30
Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

Submitting verification for [StableCoinWBTC] "0x513be19378C375466e29D6b4d001E995FBA8c2ce".
Contract successfully verified
Start verifying contract `0x7B82B239448B30372337fC22cFA02e9E7F10E812` deployed on sepolia
EVM version: cancun
Compiler version: 0.8.30
Constructor args: 0000000000000000000000006c6ad692489a89514bd4c8e9344a0bc387c32438000000000000000000000000fff9976782d46cc05630d1f6ebab18b2324d6b14000000000000000000000000694aa1769357215de4fac081bf1f309adc325306
Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

Submitting verification for [StableCoinEngine] "0x7B82B239448B30372337fC22cFA02e9E7F10E812".
Contract successfully verified
Start verifying contract `0x41233B5b9fAc54512ea322668AC20107F89A7562` deployed on sepolia
EVM version: cancun
Compiler version: 0.8.30
Constructor args: 000000000000000000000000513be19378c375466e29d6b4d001e995fba8c2ce00000000000000000000000029f2d40b0605204364af54ec677bd022da425d030000000000000000000000001b44f3514812d835eb1bdb0acb33d3fa3351ee43
Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

Submitting verification for [stablecoinWBTCEngine] "0x41233B5b9fAc54512ea322668AC20107F89A7562".
Contract successfully verified
Start verifying contract `0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee` deployed on sepolia
EVM version: cancun
Compiler version: 0.8.30
Constructor args: 00000000000000000000000041233b5b9fac54512ea322668ac20107f89a75620000000000000000000000007b82b239448b30372337fc22cfa02e9e7f10e8120000000000000000000000006c6ad692489a89514bd4c8e9344a0bc387c32438000000000000000000000000513be19378c375466e29d6b4d001e995fba8c2ce
Attempting to verify on Sourcify. Pass the --etherscan-api-key <API_KEY> to verify on Etherscan, or use the --verifier flag to verify on another provider.

Submitting verification for [DEX] "0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee".
Contract successfully verified
All (5) contracts were verified!

Transactions saved to: /home/amlan/solidity/stablecoin-dex/broadcast/DeployScript.s.sol/11155111/run-latest.json

Sensitive values saved to: /home/amlan/solidity/stablecoin-dex/cache/DeployScript.s.sol/11155111/run-latest.json