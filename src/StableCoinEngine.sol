// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import {StableCoin} from "./Stablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

contract StableCoinEngine {
    StableCoin public stableCoin;
    IERC20 public weth;
    AggregatorV3Interface public priceFeed;

    constructor(
        address _stableCoin,
        address _weth,
        address _priceFeed
    ){
        stableCoin = StableCoin(_stableCoin);
        weth = IERC20(_weth);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    } 
    function depositCollateralAndMintStableCoin(uint256 _amount, uint256 _mintAmount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(_mintAmount > 0, "Mint amount must be greater than zero");
        uint256 collateralValue = (_amount * getLatestPrice()) / 1e8;
        require(collateralValue >= _mintAmount, "Insufficient collateral value");
        bool success = weth.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        stableCoin.mint(msg.sender, _mintAmount);
    }
    function burnStableCoinAndWithdrawCollateral(uint256 _burnAmount, uint256 _withdrawAmount) public {
        require(_burnAmount > 0, "Burn amount must be greater than zero");
        require(_withdrawAmount > 0, "Withdraw amount must be greater than zero");
        uint256 collateralValue = (_withdrawAmount * getLatestPrice()) / 1e8;
        require(collateralValue <= (_burnAmount), "Insufficient burn amount for the requested withdrawal");
        stableCoin.burn(_burnAmount);
        bool success = weth.transfer(msg.sender, _withdrawAmount);
        require(success, "Transfer failed");
    }
    



}