// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";
import {StableCoinWBTC} from "./StablecoinWBTC.sol";
contract stablecoinWBTCEngine {
    StableCoinWBTC public stablecoinWBTC;
    IERC20 public wbtc;
    AggregatorV3Interface public priceFeed;
    mapping(address => uint256) public collateralDeposits;
    mapping(address => uint256) public stablecoinWBTCHoldings;

    constructor(
        address _stablecoinWBTC,
        address _wbtc,
        address _priceFeed
    ){
        stablecoinWBTC = StableCoinWBTC(_stablecoinWBTC);
        wbtc = IERC20(_wbtc);
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int price, , , ) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        return uint256(price);
    }
    function depositCollateral(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        bool success = wbtc.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        collateralDeposits[msg.sender] += _amount;
    } 
    function depositCollateralAndMintstablecoinWBTC(uint256 _amount, uint256 _mintAmount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(_mintAmount > 0, "Mint amount must be greater than zero");
        uint256 collateralValue = (_amount * getLatestPrice()) / 1e8;
        require(collateralValue >= _mintAmount, "Insufficient collateral value");
        bool success = wbtc.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        stablecoinWBTC.mint(msg.sender, _mintAmount);
        collateralDeposits[msg.sender] += _amount;
        stablecoinWBTCHoldings[msg.sender] += _mintAmount;
    }
    function burnstablecoinWBTCAndWithdrawCollateral(uint256 _burnAmount, uint256 _withdrawAmount) public {
        require(_burnAmount <= stablecoinWBTCHoldings[msg.sender], "Insufficient stablecoinWBTC holdings to burn");
        require(_burnAmount > 0, "Burn amount must be greater than zero");
        require(_withdrawAmount > 0, "Withdraw amount must be greater than zero");
        uint256 collateralValue = (_withdrawAmount * getLatestPrice()) / 1e8;
        require(collateralValue <= (_burnAmount), "Insufficient burn amount for the requested");
        stablecoinWBTC.burn(_burnAmount);
        bool success = wbtc.transfer(msg.sender, _withdrawAmount);
        require(success, "Transfer failed");
        collateralDeposits[msg.sender] -= _withdrawAmount;
        stablecoinWBTCHoldings[msg.sender] -= _burnAmount;
    }
    function getCollateralValue(address _user) public view returns (uint256) {
        uint256 collateralAmount = collateralDeposits[_user];
        return (collateralAmount * getLatestPrice()) / 1e8;
    }
    function liquidate(address _user, uint256 _debtToCover) public {
        require(_user != address(0), "Invalid user address");
        require(_debtToCover > 0, "Debt to cover must be greater than zero");
        uint256 userDebt = stablecoinWBTCHoldings[_user];
        require(userDebt >= _debtToCover, "User debt is less than the amount to cover");
        uint256 collateralToSeize = (_debtToCover * 1e8) / getLatestPrice();
        require(collateralDeposits[_user] >= collateralToSeize, "Not enough collateral to seize");
        stablecoinWBTC.burnFrom(msg.sender, _debtToCover);
        bool success = wbtc.transfer(msg.sender, collateralToSeize);
        require(success, "Transfer failed");
        collateralDeposits[_user] -= collateralToSeize;
        stablecoinWBTCHoldings[_user] -= _debtToCover;
    }
    function getUserDetails(address _user) public view returns (uint256, uint256, uint256) {
        uint256 collateralValue = getCollateralValue(_user);
        uint256 debt = stablecoinWBTCHoldings[_user];
        uint256 healthFactor = calculateHealthFactor(_user);
        return (collateralValue, debt, healthFactor);
    }
    function calculateHealthFactor(address _user) public view returns (uint256) {
        uint256 collateralValue = getCollateralValue(_user);
        uint256 debt = stablecoinWBTCHoldings[_user];
        if (debt == 0) {
            return type(uint256).max;
        }
        return (collateralValue * 1e18) / debt;
    }
}