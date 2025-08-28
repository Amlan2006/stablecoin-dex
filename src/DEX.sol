// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;
import {stablecoinWBTCEngine} from "./StablecoinWBTCEngine.sol";
import {StableCoinEngine} from "./StableCoinEngine.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DEX {
    stablecoinWBTCEngine public stablecoinWBTCEngineContract;
    StableCoinEngine public stableCoinEngineContract;
    uint256 public totalLiquidityWETH;
    uint256 public totalLiquidityWBTC;
    constructor(
        address _stablecoinWBTCEngine,
        address _stableCoinEngine
    ) {
        stablecoinWBTCEngineContract = stablecoinWBTCEngine(_stablecoinWBTCEngine);
        stableCoinEngineContract = StableCoinEngine(_stableCoinEngine);
     
    }
    function depositWBTCCollateralAndMintstablecoinWBTC(uint256 _wbtcAmount, uint256 _mintAmount) public {
        stablecoinWBTCEngineContract.depositCollateralAndMintstablecoinWBTC(_wbtcAmount, _mintAmount);
        totalLiquidityWBTC += _wbtcAmount*1e18;
    }
    function depositWETHCollateralAndMintStableCoin(uint256 _wethAmount, uint256 _mintAmount) public {
        stableCoinEngineContract.depositCollateralAndMintStableCoin(_wethAmount, _mintAmount);
        totalLiquidityWETH += _wethAmount*1e18;
    }
    function getWBTCCollateralValue(address _user) public view returns (uint256) {
        return stablecoinWBTCEngineContract.getCollateralValue(_user);
    }
    function getWETHCollateralValue(address _user) public view returns (uint256) {
        return stableCoinEngineContract.getCollateralValue(_user);
    }
    function calculateSwapEthToWbtc(uint256 _ethAmount) public view returns (uint256) {
        require(_ethAmount > 0, "Amount must be greater than zero");
        require(totalLiquidityWETH > 0 && totalLiquidityWBTC > 0, "Insufficient liquidity");
        uint256 ethReserve = totalLiquidityWETH;
        uint256 wbtcReserve = totalLiquidityWBTC;
        uint256 wbtcAmount = ( _ethAmount*1e18 * wbtcReserve ) / ( ethReserve + _ethAmount*1e18 );
        return wbtcAmount;
    }
    function calculateSwapWbtcToEth(uint256 _wbtcAmount) public view returns (uint256) {
        require(_wbtcAmount > 0, "Amount must be greater than zero");
        require(totalLiquidityWETH > 0 && totalLiquidityWBTC > 0, "Insufficient liquidity");
        uint256 ethReserve = totalLiquidityWETH;
        uint256 wbtcReserve = totalLiquidityWBTC;
        uint256 ethAmount = ( _wbtcAmount * ethReserve ) / ( wbtcReserve + _wbtcAmount );
        return ethAmount;
    }

   
}
    
