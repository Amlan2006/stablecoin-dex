// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import {StableCoin} from "./Stablecoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.4/interfaces/AggregatorV3Interface.sol";

contract StableCoinEngine {
    StableCoin public stableCoin;
    IERC20 public weth;
    AggregatorV3Interface public priceFeed;
    mapping(address => uint256) public collateralDeposits;
    mapping(address => uint256) public stableCoinHoldings;

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
    function depositCollateral(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        bool success = weth.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        collateralDeposits[msg.sender] += _amount;
    } 
    function depositCollateralAndMintStableCoin(uint256 _amount, uint256 _mintAmount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(_mintAmount > 0, "Mint amount must be greater than zero");
        uint256 collateralValue = (_amount * getLatestPrice()) / 1e8;
        require(collateralValue >= _mintAmount, "Insufficient collateral value");
        bool success = weth.transferFrom(msg.sender, address(this), _amount);
        require(success, "Transfer failed");
        stableCoin.mint(msg.sender, _mintAmount);
        collateralDeposits[msg.sender] += _amount;
        stableCoinHoldings[msg.sender] += _mintAmount;
    }
    function burnStableCoinAndWithdrawCollateral(uint256 _burnAmount, uint256 _withdrawAmount) public {
        require(_burnAmount <= stableCoinHoldings[msg.sender], "Insufficient stablecoin holdings to burn");
        require(_burnAmount > 0, "Burn amount must be greater than zero");
        require(_withdrawAmount > 0, "Withdraw amount must be greater than zero");
        uint256 collateralValue = (_withdrawAmount * getLatestPrice()) / 1e8;
        require(collateralValue <= (_burnAmount), "Insufficient burn amount for the requested withdrawal");
        stableCoin.burn(_burnAmount);
        bool success = weth.transfer(msg.sender, _withdrawAmount);
        require(success, "Transfer failed");
        collateralDeposits[msg.sender] -= _withdrawAmount;
        stableCoinHoldings[msg.sender] -= _burnAmount;
    }

    function getCollateralValue(address _user) public view returns (uint256) {
        uint256 collateralAmount = collateralDeposits[_user];
        return (collateralAmount * getLatestPrice()) / 1e8;
    }
    function calculateHealthFactor(address _user) public view returns (uint256) {
        uint256 collateralValue = getCollateralValue(_user);
        uint256 debt = stableCoinHoldings[_user];
        if (debt == 0) {
            return type(uint256).max;
        }
        return (collateralValue * 1e18) / debt;
    }
    function _healthFactorOk(address _user) internal view returns (bool) {
        uint256 healthFactor = calculateHealthFactor(_user);
        return healthFactor >= 150e16; // 1.5 in 18 decimal places
    }
    function liquidate(address _user, uint256 _debtToCover) public {
        require(!_healthFactorOk(_user), "Health factor is ok");
        require(_debtToCover > 0, "Debt to cover must be greater than zero");
        uint256 userDebt = stableCoinHoldings[_user];
        require(userDebt >= _debtToCover, "User debt is less than the amount to cover");
        // uint256 collateralValue = getCollateralValue(_user);
        uint256 collateralToSeize = (_debtToCover * 1e8) / getLatestPrice();
        require(collateralDeposits[_user] >= collateralToSeize, "Not enough collateral to seize");
        stableCoin.burnFrom(msg.sender, _debtToCover);
        bool success = weth.transfer(msg.sender, collateralToSeize);
        require(success, "Transfer failed");
        collateralDeposits[_user] -= collateralToSeize;
        stableCoinHoldings[_user] -= _debtToCover;
        require(_healthFactorOk(_user), "Health factor still not ok after liquidation");
    }
    function getUserDetails(address _user) public view returns (uint256, uint256, uint256) {
        uint256 collateralValue = getCollateralValue(_user);
        uint256 debt = stableCoinHoldings[_user];
        uint256 healthFactor = calculateHealthFactor(_user);
        return (collateralValue, debt, healthFactor);
    }
  






}