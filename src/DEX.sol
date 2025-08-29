// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import {stablecoinWBTCEngine} from "./StablecoinWBTCEngine.sol";
import {StableCoinEngine} from "./StableCoinEngine.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DEX {
    stablecoinWBTCEngine public stablecoinWBTCEngineContract;
    StableCoinEngine public stableCoinEngineContract;
    IERC20 public stablecoin;     // sETH
    IERC20 public stablecoinWbtc; // sBTC

    constructor(
        address _stablecoinWBTCEngine,
        address _stableCoinEngine,
        address _stableCoin,
        address _stablecoinWBTC
    ) {
        stablecoinWBTCEngineContract = stablecoinWBTCEngine(_stablecoinWBTCEngine);
        stableCoinEngineContract = StableCoinEngine(_stableCoinEngine);
        stablecoin = IERC20(_stableCoin);
        stablecoinWbtc = IERC20(_stablecoinWBTC);
    }

    /* -------------------- wrappers to engines -------------------- */
    function depositWBTCCollateralAndMintstablecoinWBTC(uint256 _wbtcAmount, uint256 _mintAmount) public {
        stablecoinWBTCEngineContract.depositCollateralAndMintstablecoinWBTC(_wbtcAmount, _mintAmount);
    }
    function depositWETHCollateralAndMintStableCoin(uint256 _wethAmount, uint256 _mintAmount) public {
        stableCoinEngineContract.depositCollateralAndMintStableCoin(_wethAmount, _mintAmount);
    }

    function getWBTCCollateralValue(address _user) public view returns (uint256) {
        return stablecoinWBTCEngineContract.getCollateralValue(_user);
    }
    function getWETHCollateralValue(address _user) public view returns (uint256) {
        return stableCoinEngineContract.getCollateralValue(_user);
    }
    function calculateHealthFactorWETH(address _user) public view returns (uint256) {
        return stableCoinEngineContract.calculateHealthFactor(_user);
    }
    function calculateHealthFactorWBTC(address _user) public view returns (uint256) {
        return stablecoinWBTCEngineContract.calculateHealthFactor(_user);
    }

    /* -------------------- exchange logic -------------------- */
    // exchangeRate = priceWBTC / priceWETH, scaled by 1e18. => WETH per WBTC
    function getExchangeRate() public view returns (uint256) {
        uint256 priceWETH = stableCoinEngineContract.getLatestPrice();
        uint256 priceWBTC = stablecoinWBTCEngineContract.getLatestPrice();
        require(priceWETH > 0 && priceWBTC > 0, "Invalid price data");
        return (priceWBTC * 1e18) / priceWETH; // Return exchange rate with 18 decimals
    }

    // *** INCOMING transfers: pull tokens from msg.sender using transfer***
    function _pullStableCoinFromSender(uint256 _amount) internal {
        require(stablecoin.transfer(address(this), _amount), "pull sETH failed");
    }
    function _pullStableCoinWBTCFromSender(uint256 _amount) internal {
        require(stablecoinWbtc.transfer(address(this), _amount), "pull sBTC failed");
    }

    // *** OUTGOING transfers: contract pays from its own balance using transfer ***
    function _sendStableCoinTo(address _to, uint256 _amount) internal {
        require(stablecoin.balanceOf(address(this)) >= _amount, "DEX: insufficient sETH liquidity");

        require(stablecoin.transfer(_to, _amount), "send sETH failed");
    }
    function _sendStableCoinWBTCTo(address _to, uint256 _amount) internal {
        require(stablecoinWbtc.balanceOf(address(this)) >= _amount, "DEX: insufficient sBTC liquidity");
        require(stablecoinWbtc.transfer(_to, _amount), "send sBTC failed");
    }

    // user gives sETH, wants sBTC
    function swapStableCoinForStableCoinWBTC(uint256 _amountIn) public {
        require(_amountIn > 0, "Amount in must be > 0");
        uint256 exchangeRate = getExchangeRate(); // WETH per WBTC
        // amountOut = amountIn / (WETH per WBTC) => convert ETH -> BTC
        uint256 amountOut = (_amountIn * 1e18) / exchangeRate;
        _pullStableCoinFromSender(_amountIn);      // pull sETH from user
        _sendStableCoinWBTCTo(msg.sender, amountOut); // send sBTC to user
    }

    // user gives sBTC, wants sETH
    function swapStableCoinWBTCForStableCoin(uint256 _amountIn) public {
        require(_amountIn > 0, "Amount in must be > 0");
        uint256 exchangeRate = getExchangeRate(); // WETH per WBTC
        // amountOut = amountIn * (WETH per WBTC) => convert BTC -> ETH
        uint256 amountOut = (_amountIn * exchangeRate) / 1e18;
        _pullStableCoinWBTCFromSender(_amountIn);    // pull sBTC from user
        _sendStableCoinTo(msg.sender, amountOut);    // send sETH to user
    }

    /* -------------------- helper / view wrappers -------------------- */
    function getUserDetails(address _user) public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        (uint256 collateralWETH, uint256 debtWETH, uint256 healthFactorWETH) = stableCoinEngineContract.getUserDetails(_user);
        (uint256 collateralWBTC, uint256 debtWBTC, uint256 healthFactorWBTC) = stablecoinWBTCEngineContract.getUserDetails(_user);
        return (collateralWETH, debtWETH, healthFactorWETH, collateralWBTC, debtWBTC, healthFactorWBTC);
    }

    function getUserDetailsWETH(address _user) public view returns (uint256, uint256, uint256) {
        return stableCoinEngineContract.getUserDetails(_user);
    }
    function getUserDetailsWBTC(address _user) public view returns (uint256, uint256, uint256) {
        return stablecoinWBTCEngineContract.getUserDetails(_user);
    }

    /* -------------------- engine passthroughs -------------------- */
    // burnStableCoin: wrapper to burn stable coin and withdraw collateral (calls engine)
    function burnStableCoin(uint256 _amount) public {
        stableCoinEngineContract.burnStableCoinAndWithdrawCollateral(_amount, _amount);
    }

    // liquidations: call engine liquidation functions (liquidator must have and approve tokens/allowances as engine requires)
    function liquidateWETH(address _user, uint256 _debtToCover) public {
        stableCoinEngineContract.liquidate(_user, _debtToCover);
    }
    function liquidateWBTC(address _user, uint256 _debtToCover) public {
        stablecoinWBTCEngineContract.liquidate(_user, _debtToCover);
    }
}
