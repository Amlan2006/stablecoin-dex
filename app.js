// Contract Addresses on Sepolia Testnet
const CONTRACT_ADDRESSES = {
    DEX: "0x708EAd15b66236310f9a18e44AFf2C3B82A671Ee",
    StableCoin: "0x6c6ad692489a89514bD4C8e9344a0Bc387c32438", // sETH
    StableCoinWBTC: "0x513be19378C375466e29D6b4d001E995FBA8c2ce", // sBTC
    StableCoinEngine: "0x7B82B239448B30372337fC22cFA02e9E7F10E812",
    StablecoinWBTCEngine: "0x41233B5b9fAc54512ea322668AC20107F89A7562",
    WETH: "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
    WBTC: "0x29f2D40B0605204364af54EC677bD022dA425d03"
};

// Contract ABIs (simplified for core functions)
const DEX_ABI = [
    "function swapStableCoinForStableCoinWBTC(uint256 _amountIn) external",
    "function swapStableCoinWBTCForStableCoin(uint256 _amountIn) external",
    "function getExchangeRate() external view returns (uint256)",
    "function getUserDetails(address _user) external view returns (uint256, uint256, uint256, uint256, uint256, uint256)",
    "function depositWETHCollateralAndMintStableCoin(uint256 _wethAmount, uint256 _mintAmount) external",
    "function depositWBTCCollateralAndMintstablecoinWBTC(uint256 _wbtcAmount, uint256 _mintAmount) external",
    "function burnStableCoin(uint256 _amount) external",
    "function liquidateWETH(address _user, uint256 _debtToCover) external",
    "function liquidateWBTC(address _user, uint256 _debtToCover) external"
];

const ERC20_ABI = [
    "function balanceOf(address owner) external view returns (uint256)",
    "function allowance(address owner, address spender) external view returns (uint256)",
    "function approve(address spender, uint256 amount) external returns (bool)",
    "function transfer(address to, uint256 amount) external returns (bool)",
    "function name() external view returns (string)",
    "function symbol() external view returns (string)",
    "function decimals() external view returns (uint8)"
];

const ENGINE_ABI = [
    "function getLatestPrice() external view returns (uint256)",
    "function getUserDetails(address _user) external view returns (uint256, uint256, uint256)"
];

// Global variables
let provider;
let signer;
let userAddress;
let contracts = {};

// Initialize the application
document.addEventListener('DOMContentLoaded', async () => {
    console.log('StableCoin DEX Frontend Initialized');
    
    setupEventListeners();
    
    if (typeof window.ethereum !== 'undefined') {
        console.log('MetaMask is installed');
        provider = new ethers.providers.Web3Provider(window.ethereum);
        
        const accounts = await window.ethereum.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
            await connectWallet();
        }
    } else {
        showNotification('Please install MetaMask to use this application', 'error');
    }
    
    setInterval(updatePrices, 30000);
    
    // Add real-time collateral ratio calculations
    document.getElementById('wethCollateral').addEventListener('input', calculateSETHCollateralRatio);
    document.getElementById('sethToMint').addEventListener('input', calculateSETHCollateralRatio);
    document.getElementById('wbtcCollateral').addEventListener('input', calculateSBTCCollateralRatio);
    document.getElementById('sbtcToMint').addEventListener('input', calculateSBTCCollateralRatio);
});

// Setup all event listeners
function setupEventListeners() {
    document.getElementById('connectWallet').addEventListener('click', connectWallet);
    document.getElementById('disconnectWallet').addEventListener('click', disconnectWallet);
    
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => switchTab(e.target.dataset.tab));
    });
    
    document.getElementById('swapDirection').addEventListener('click', swapTokenDirection);
    document.getElementById('fromAmount').addEventListener('input', calculateSwapOutput);
    document.getElementById('swapBtn').addEventListener('click', executeSwap);
    
    document.getElementById('mintSETH').addEventListener('click', mintSETH);
    document.getElementById('mintSBTC').addEventListener('click', mintSBTC);
    
    document.getElementById('burnSETH').addEventListener('click', burnSETH);
    document.getElementById('checkPosition').addEventListener('click', checkLiquidationTarget);
    document.getElementById('liquidatePosition').addEventListener('click', executeLiquidation);
}

// Wallet connection functions
async function connectWallet() {
    try {
        if (!window.ethereum) {
            throw new Error('MetaMask not installed');
        }
        
        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        userAddress = accounts[0];
        
        provider = new ethers.providers.Web3Provider(window.ethereum);
        signer = provider.getSigner();
        
        const network = await provider.getNetwork();
        if (network.chainId !== 11155111) {
            try {
                await window.ethereum.request({
                    method: 'wallet_switchEthereumChain',
                    params: [{ chainId: '0xaa36a7' }],
                });
            } catch (switchError) {
                showNotification('Please switch to Sepolia testnet', 'error');
                return;
            }
        }
        
        await initializeContracts();
        
        document.getElementById('connectWallet').style.display = 'none';
        document.getElementById('walletInfo').style.display = 'flex';
        document.getElementById('walletAddress').textContent = `${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
        
        await loadUserData();
        showNotification('Wallet connected successfully!', 'success');
    } catch (error) {
        console.error('Failed to connect wallet:', error);
        showNotification(`Failed to connect wallet: ${error.message}`, 'error');
    }
}

async function disconnectWallet() {
    userAddress = null;
    provider = null;
    signer = null;
    contracts = {};
    
    document.getElementById('connectWallet').style.display = 'block';
    document.getElementById('walletInfo').style.display = 'none';
    
    resetAllData();
    showNotification('Wallet disconnected', 'info');
}

async function initializeContracts() {
    contracts.dex = new ethers.Contract(CONTRACT_ADDRESSES.DEX, DEX_ABI, signer);
    contracts.stableCoin = new ethers.Contract(CONTRACT_ADDRESSES.StableCoin, ERC20_ABI, signer);
    contracts.stableCoinWBTC = new ethers.Contract(CONTRACT_ADDRESSES.StableCoinWBTC, ERC20_ABI, signer);
    contracts.stableCoinEngine = new ethers.Contract(CONTRACT_ADDRESSES.StableCoinEngine, ENGINE_ABI, provider);
    contracts.stablecoinWBTCEngine = new ethers.Contract(CONTRACT_ADDRESSES.StablecoinWBTCEngine, ENGINE_ABI, provider);
    contracts.weth = new ethers.Contract(CONTRACT_ADDRESSES.WETH, ERC20_ABI, signer);
    contracts.wbtc = new ethers.Contract(CONTRACT_ADDRESSES.WBTC, ERC20_ABI, signer);
}

function switchTab(tabName) {
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
    
    document.querySelectorAll('.tab-content').forEach(content => content.classList.remove('active'));
    document.getElementById(tabName).classList.add('active');
    
    if (userAddress) {
        switch(tabName) {
            case 'trading':
                loadTradingData();
                break;
            case 'portfolio':
                loadPortfolioData();
                break;
        }
    }
}

function swapTokenDirection() {
    const fromToken = document.getElementById('fromToken');
    const toToken = document.getElementById('toToken');
    const fromAmount = document.getElementById('fromAmount');
    const toAmount = document.getElementById('toAmount');
    
    const tempValue = fromToken.value;
    fromToken.value = toToken.value;
    toToken.value = tempValue;
    
    fromAmount.value = '';
    toAmount.value = '';
    
    if (userAddress) {
        loadTradingData();
    }
}

async function calculateSwapOutput() {
    const fromAmount = document.getElementById('fromAmount').value;
    const fromToken = document.getElementById('fromToken').value;
    
    if (!fromAmount || !contracts.dex) return;
    
    try {
        const exchangeRate = await contracts.dex.getExchangeRate();
        const amountIn = ethers.utils.parseEther(fromAmount);
        
        let amountOut;
        if (fromToken === 'sETH') {
            amountOut = amountIn.mul(ethers.utils.parseEther('1')).div(exchangeRate);
        } else {
            amountOut = amountIn.mul(exchangeRate).div(ethers.utils.parseEther('1'));
        }
        
        document.getElementById('toAmount').value = ethers.utils.formatEther(amountOut);
        
        // Check DEX liquidity for the output token
        await checkDEXLiquidity(fromToken, amountOut);
        
    } catch (error) {
        console.error('Failed to calculate swap output:', error);
        document.getElementById('toAmount').value = '';
    }
}

// New function to check DEX liquidity
async function checkDEXLiquidity(fromToken, amountOut) {
    try {
        const outputToken = fromToken === 'sETH' ? 'sBTC' : 'sETH';
        const outputContract = fromToken === 'sETH' ? contracts.stableCoinWBTC : contracts.stableCoin;
        
        const dexBalance = await outputContract.balanceOf(CONTRACT_ADDRESSES.DEX);
        
        const liquidityWarning = document.getElementById('liquidityWarning') || createLiquidityWarning();
        
        if (dexBalance.lt(amountOut)) {
            liquidityWarning.style.display = 'block';
            liquidityWarning.innerHTML = `
                🚨 <strong>Insufficient DEX Liquidity!</strong><br>
                DEX has ${ethers.utils.formatEther(dexBalance)} ${outputToken}<br>
                but you need ${ethers.utils.formatEther(amountOut)} ${outputToken}<br>
                <small>Try a smaller amount or add liquidity to the DEX</small>
            `;
            liquidityWarning.className = 'liquidity-warning error';
        } else {
            liquidityWarning.style.display = 'block';
            liquidityWarning.innerHTML = `
                ✅ <strong>Sufficient Liquidity</strong><br>
                DEX has ${ethers.utils.formatEther(dexBalance)} ${outputToken}<br>
                Swap amount: ${ethers.utils.formatEther(amountOut)} ${outputToken}
            `;
            liquidityWarning.className = 'liquidity-warning success';
        }
    } catch (error) {
        console.error('Failed to check DEX liquidity:', error);
    }
}

function createLiquidityWarning() {
    const warning = document.createElement('div');
    warning.id = 'liquidityWarning';
    warning.className = 'liquidity-warning';
    warning.style.display = 'none';
    
    const swapContainer = document.querySelector('.swap-container');
    const exchangeRate = document.querySelector('.exchange-rate');
    swapContainer.insertBefore(warning, exchangeRate);
    
    return warning;
}

async function executeSwap() {
    const fromAmount = document.getElementById('fromAmount').value;
    const fromToken = document.getElementById('fromToken').value;
    
    if (!fromAmount || !userAddress) {
        showNotification('Please enter an amount and connect your wallet', 'error');
        return;
    }
    
    try {
        showLoading(true);
        
        const amountIn = ethers.utils.parseEther(fromAmount);
        const tokenContract = fromToken === 'sETH' ? contracts.stableCoin : contracts.stableCoinWBTC;
        
        // Check token balance first
        const tokenBalance = await tokenContract.balanceOf(userAddress);
        if (tokenBalance.lt(amountIn)) {
            throw new Error(`Insufficient ${fromToken} balance. You have ${ethers.utils.formatEther(tokenBalance)} ${fromToken} but need ${fromAmount} ${fromToken}`);
        }
        
        // Check DEX liquidity before proceeding
        const exchangeRate = await contracts.dex.getExchangeRate();
        let amountOut;
        if (fromToken === 'sETH') {
            amountOut = amountIn.mul(ethers.utils.parseEther('1')).div(exchangeRate);
        } else {
            amountOut = amountIn.mul(exchangeRate).div(ethers.utils.parseEther('1'));
        }
        
        const outputToken = fromToken === 'sETH' ? 'sBTC' : 'sETH';
        const outputContract = fromToken === 'sETH' ? contracts.stableCoinWBTC : contracts.stableCoin;
        const dexOutputBalance = await outputContract.balanceOf(CONTRACT_ADDRESSES.DEX);
        
        if (dexOutputBalance.lt(amountOut)) {
            throw new Error(`DEX has insufficient ${outputToken} liquidity. Available: ${ethers.utils.formatEther(dexOutputBalance)} ${outputToken}, Required: ${ethers.utils.formatEther(amountOut)} ${outputToken}. Please try a smaller amount or consider adding liquidity to the DEX.`);
        }
        
        await checkAndApprove(tokenContract, CONTRACT_ADDRESSES.DEX, amountIn);
        
        let tx;
        try {
            if (fromToken === 'sETH') {
                await contracts.dex.estimateGas.swapStableCoinForStableCoinWBTC(amountIn);
                tx = await contracts.dex.swapStableCoinForStableCoinWBTC(amountIn, {
                    gasLimit: 300000
                });
            } else {
                await contracts.dex.estimateGas.swapStableCoinWBTCForStableCoin(amountIn);
                tx = await contracts.dex.swapStableCoinWBTCForStableCoin(amountIn, {
                    gasLimit: 300000
                });
            }
        } catch (estimateError) {
            if (estimateError.message.includes('execution reverted')) {
                throw new Error('Swap would fail. Please check: 1) Sufficient token balance, 2) DEX has enough liquidity for the swap, 3) Valid amounts entered');
            }
            throw estimateError;
        }
        
        showNotification('Transaction submitted. Waiting for confirmation...', 'info');
        await tx.wait();
        
        showNotification('Swap completed successfully!', 'success');
        
        document.getElementById('fromAmount').value = '';
        document.getElementById('toAmount').value = '';
        
        // Hide liquidity warning after successful swap
        const liquidityWarning = document.getElementById('liquidityWarning');
        if (liquidityWarning) {
            liquidityWarning.style.display = 'none';
        }
        
        await loadTradingData();
        
    } catch (error) {
        console.error('Swap failed:', error);
        
        // Enhanced error handling
        if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
            showNotification('Swap would fail. Check token balance and DEX liquidity', 'error');
        } else if (error.code === 'INSUFFICIENT_FUNDS') {
            showNotification('Insufficient funds for gas fees', 'error');
        } else if (error.code === 4001) {
            showNotification('Transaction rejected by user', 'warning');
        } else if (error.message.includes('execution reverted')) {
            showNotification(`Swap failed: ${error.message}`, 'error');
        } else if (error.message.includes('DEX has insufficient')) {
            showNotification(`Liquidity Error: ${error.message}`, 'error');
        } else {
            showNotification(`Swap failed: ${error.message}`, 'error');
        }
    } finally {
        showLoading(false);
    }
}

async function mintSETH() {
    const wethAmount = document.getElementById('wethCollateral').value;
    const sethAmount = document.getElementById('sethToMint').value;
    
    if (!wethAmount || !sethAmount || !userAddress) {
        showNotification('Please enter amounts and connect your wallet', 'error');
        return;
    }
    
    try {
        showLoading(true);
        
        const wethAmountWei = ethers.utils.parseEther(wethAmount);
        const sethAmountWei = ethers.utils.parseEther(sethAmount);
        
        // Check WETH balance first
        const wethBalance = await contracts.weth.balanceOf(userAddress);
        if (wethBalance.lt(wethAmountWei)) {
            throw new Error(`Insufficient WETH balance. You have ${ethers.utils.formatEther(wethBalance)} WETH but need ${wethAmount} WETH`);
        }
        
        // Check and approve WETH
        await checkAndApprove(contracts.weth, CONTRACT_ADDRESSES.DEX, wethAmountWei);
        
        // Try to estimate gas first to catch errors early
        try {
            await contracts.dex.estimateGas.depositWETHCollateralAndMintStableCoin(wethAmountWei, sethAmountWei);
        } catch (estimateError) {
            console.error('Gas estimation failed:', estimateError);
            
            // Provide specific error messages based on common failure reasons
            // if (estimateError.message.includes('execution reverted')) {
            //     // Check common failure reasons
            //     const ethPrice = await contracts.stableCoinEngine.getLatestPrice();
            //     const collateralValue = wethAmountWei.mul(ethPrice).div(ethers.utils.parseEther('1'));
            //     const collateralRatio = collateralValue.mul(100).div(sethAmountWei);
                
            //     if (collateralRatio.lt(150)) {
            //         throw new Error(`Collateral ratio too low (${collateralRatio}%). Minimum 150% required. Either increase WETH collateral or decrease sETH mint amount.`);
            //     }
                
            //     throw new Error('Transaction would fail. Please check: 1) Sufficient WETH balance, 2) Collateral ratio ≥ 150%, 3) Valid amounts entered');
            
            
            throw new Error(`Gas estimation failed: ${estimateError.message}`);
        }
        
        const tx = await contracts.dex.depositWETHCollateralAndMintStableCoin(wethAmountWei, sethAmountWei, {
            gasLimit: 500000 // Set manual gas limit as fallback
        });
        
        showNotification('Transaction submitted. Waiting for confirmation...', 'info');
        await tx.wait();
        
        showNotification('sETH minted successfully!', 'success');
        
        document.getElementById('wethCollateral').value = '';
        document.getElementById('sethToMint').value = '';
        
    } catch (error) {
        console.error('Mint sETH failed:', error);
        
        // Enhanced error handling with specific cases
        if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
            showNotification('Transaction would fail. Check your WETH balance and ensure collateral ratio is at least 150%', 'error');
        } else if (error.code === 'INSUFFICIENT_FUNDS') {
            showNotification('Insufficient funds for gas fees', 'error');
        } else if (error.code === 4001) {
            showNotification('Transaction rejected by user', 'warning');
        } else if (error.message.includes('execution reverted')) {
            showNotification(`Transaction failed: ${error.message}`, 'error');
        } else {
            showNotification(`Mint failed: ${error.message}`, 'error');
        }
    } finally {
        showLoading(false);
    }
}

async function mintSBTC() {
    const wbtcAmount = document.getElementById('wbtcCollateral').value;
    const sbtcAmount = document.getElementById('sbtcToMint').value;
    
    if (!wbtcAmount || !sbtcAmount || !userAddress) {
        showNotification('Please enter amounts and connect your wallet', 'error');
        return;
    }
    
    try {
        showLoading(true);
        
        const wbtcAmountWei = ethers.utils.parseUnits(wbtcAmount, 8);
        const sbtcAmountWei = ethers.utils.parseUnits(sbtcAmount, 8);
        
        // Check WBTC balance first
        const wbtcBalance = await contracts.wbtc.balanceOf(userAddress);
        if (wbtcBalance.lt(wbtcAmountWei)) {
            throw new Error(`Insufficient WBTC balance. You have ${ethers.utils.formatUnits(wbtcBalance, 8)} WBTC but need ${wbtcAmount} WBTC`);
        }
        
        // Check and approve WBTC
        await checkAndApprove(contracts.wbtc, CONTRACT_ADDRESSES.DEX, wbtcAmountWei);
        
        // Try to estimate gas first to catch errors early
        try {
            await contracts.dex.estimateGas.depositWBTCCollateralAndMintstablecoinWBTC(wbtcAmountWei, sbtcAmountWei);
        } catch (estimateError) {
            console.error('Gas estimation failed:', estimateError);
            
            // Provide specific error messages based on common failure reasons
            if (estimateError.message.includes('execution reverted')) {
                // Check common failure reasons
                const btcPrice = await contracts.stablecoinWBTCEngine.getLatestPrice();
                const collateralValue = wbtcAmountWei.mul(btcPrice).div(ethers.utils.parseUnits('1', 8));
                const collateralRatio = collateralValue.mul(100).div(sbtcAmountWei);
                
                if (collateralRatio.lt(150)) {
                    throw new Error(`Collateral ratio too low (${collateralRatio}%). Minimum 150% required. Either increase WBTC collateral or decrease sBTC mint amount.`);
                }
                
                throw new Error('Transaction would fail. Please check: 1) Sufficient WBTC balance, 2) Collateral ratio ≥ 150%, 3) Valid amounts entered');
            }
            
            throw new Error(`Gas estimation failed: ${estimateError.message}`);
        }
        
        const tx = await contracts.dex.depositWBTCCollateralAndMintstablecoinWBTC(wbtcAmountWei, sbtcAmountWei, {
            gasLimit: 500000 // Set manual gas limit as fallback
        });
        
        showNotification('Transaction submitted. Waiting for confirmation...', 'info');
        await tx.wait();
        
        showNotification('sBTC minted successfully!', 'success');
        
        document.getElementById('wbtcCollateral').value = '';
        document.getElementById('sbtcToMint').value = '';
        
    } catch (error) {
        console.error('Mint sBTC failed:', error);
        
        // Enhanced error handling with specific cases
        if (error.code === 'UNPREDICTABLE_GAS_LIMIT') {
            showNotification('Transaction would fail. Check your WBTC balance and ensure collateral ratio is at least 150%', 'error');
        } else if (error.code === 'INSUFFICIENT_FUNDS') {
            showNotification('Insufficient funds for gas fees', 'error');
        } else if (error.code === 4001) {
            showNotification('Transaction rejected by user', 'warning');
        } else if (error.message.includes('execution reverted')) {
            showNotification(`Transaction failed: ${error.message}`, 'error');
        } else {
            showNotification(`Mint failed: ${error.message}`, 'error');
        }
    } finally {
        showLoading(false);
    }
}

async function burnSETH() {
    const amount = prompt('Enter amount of sETH to burn:');
    if (!amount || !userAddress) return;
    
    try {
        showLoading(true);
        
        const amountWei = ethers.utils.parseEther(amount);
        await checkAndApprove(contracts.stableCoin, CONTRACT_ADDRESSES.DEX, amountWei);
        
        const tx = await contracts.dex.burnStableCoin(amountWei);
        
        showNotification('Transaction submitted. Waiting for confirmation...', 'info');
        await tx.wait();
        
        showNotification('sETH burned successfully!', 'success');
        await loadPortfolioData();
        
    } catch (error) {
        console.error('Burn sETH failed:', error);
        showNotification(`Burn failed: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

async function checkLiquidationTarget() {
    const targetAddress = document.getElementById('liquidationTarget').value;
    
    if (!targetAddress || !ethers.utils.isAddress(targetAddress)) {
        showNotification('Please enter a valid address', 'error');
        return;
    }
    
    try {
        const userDetails = await contracts.dex.getUserDetails(targetAddress);
        const [wethCollateral, wethDebt, wethHealthFactor] = [userDetails[0], userDetails[1], userDetails[2]];
        
        document.getElementById('targetCollateral').textContent = ethers.utils.formatEther(wethCollateral);
        document.getElementById('targetDebt').textContent = ethers.utils.formatEther(wethDebt);
        document.getElementById('targetHealthFactor').textContent = (wethHealthFactor.toNumber() / 1e18).toFixed(2);
        
        if (wethHealthFactor.lt(ethers.utils.parseEther('1.2'))) {
            showNotification('Warning: This position may be eligible for liquidation', 'warning');
        }
        
    } catch (error) {
        console.error('Failed to check position:', error);
        showNotification(`Failed to check position: ${error.message}`, 'error');
    }
}

async function executeLiquidation() {
    const targetAddress = document.getElementById('liquidationTarget').value;
    const debtToCover = document.getElementById('debtToCover').value;
    
    if (!targetAddress || !debtToCover || !userAddress) {
        showNotification('Please fill all fields and connect your wallet', 'error');
        return;
    }
    
    try {
        showLoading(true);
        
        const debtAmount = ethers.utils.parseEther(debtToCover);
        await checkAndApprove(contracts.stableCoin, CONTRACT_ADDRESSES.DEX, debtAmount);
        
        const tx = await contracts.dex.liquidateWETH(targetAddress, debtAmount);
        
        showNotification('Liquidation transaction submitted. Waiting for confirmation...', 'info');
        await tx.wait();
        
        showNotification('Liquidation completed successfully!', 'success');
        
        document.getElementById('liquidationTarget').value = '';
        document.getElementById('debtToCover').value = '';
        
    } catch (error) {
        console.error('Liquidation failed:', error);
        showNotification(`Liquidation failed: ${error.message}`, 'error');
    } finally {
        showLoading(false);
    }
}

async function loadUserData() {
    await Promise.all([
        loadTradingData(),
        loadPortfolioData(),
        updatePrices()
    ]);
}

async function loadTradingData() {
    if (!userAddress || !contracts.stableCoin) return;
    
    try {
        const [sethBalance, sbtcBalance, dexSethBalance, dexSbtcBalance] = await Promise.all([
            contracts.stableCoin.balanceOf(userAddress),
            contracts.stableCoinWBTC.balanceOf(userAddress),
            contracts.stableCoin.balanceOf(CONTRACT_ADDRESSES.DEX),
            contracts.stableCoinWBTC.balanceOf(CONTRACT_ADDRESSES.DEX)
        ]);
        
        const fromToken = document.getElementById('fromToken').value;
        const toToken = document.getElementById('toToken').value;
        
        document.getElementById('fromBalance').textContent = fromToken === 'sETH' 
            ? ethers.utils.formatEther(sethBalance)
            : ethers.utils.formatEther(sbtcBalance);
            
        document.getElementById('toBalance').textContent = toToken === 'sETH' 
            ? ethers.utils.formatEther(sethBalance)
            : ethers.utils.formatEther(sbtcBalance);
        
        // Update DEX liquidity display
        updateDEXLiquidityDisplay(dexSethBalance, dexSbtcBalance);
            
    } catch (error) {
        console.error('Failed to load trading data:', error);
    }
}

function updateDEXLiquidityDisplay(dexSethBalance, dexSbtcBalance) {
    // Create or update DEX liquidity display
    let liquidityDisplay = document.getElementById('dexLiquidityDisplay');
    if (!liquidityDisplay) {
        liquidityDisplay = document.createElement('div');
        liquidityDisplay.id = 'dexLiquidityDisplay';
        liquidityDisplay.className = 'dex-liquidity-display';
        
        const tradingCard = document.querySelector('#trading .card');
        const swapContainer = document.querySelector('.swap-container');
        tradingCard.insertBefore(liquidityDisplay, swapContainer);
    }
    
    liquidityDisplay.innerHTML = `
        <h4>💰 DEX Liquidity Pool</h4>
        <div class="liquidity-stats">
            <div class="liquidity-stat">
                <span class="token-name">sETH:</span>
                <span class="token-amount">${ethers.utils.formatEther(dexSethBalance)}</span>
            </div>
            <div class="liquidity-stat">
                <span class="token-name">sBTC:</span>
                <span class="token-amount">${ethers.utils.formatEther(dexSbtcBalance)}</span>
            </div>
        </div>
        <p class="liquidity-note">💡 <small>These are the available tokens in the DEX for swapping</small></p>
    `;
}

async function loadPortfolioData() {
    if (!userAddress || !contracts.dex) return;
    
    try {
        const userDetails = await contracts.dex.getUserDetails(userAddress);
        const [wethCollateral, wethDebt, wethHealthFactor, wbtcCollateral, wbtcDebt, wbtcHealthFactor] = userDetails;
        
        document.getElementById('wethPositionCollateral').textContent = ethers.utils.formatEther(wethCollateral);
        document.getElementById('wethPositionDebt').textContent = ethers.utils.formatEther(wethDebt);
        document.getElementById('wethHealthFactor').textContent = wethHealthFactor.gt(0) 
            ? (wethHealthFactor.toNumber() / 1e18).toFixed(2) 
            : '--';
        
        document.getElementById('wbtcPositionCollateral').textContent = ethers.utils.formatUnits(wbtcCollateral, 8);
        document.getElementById('wbtcPositionDebt').textContent = ethers.utils.formatUnits(wbtcDebt, 8);
        document.getElementById('wbtcHealthFactor').textContent = wbtcHealthFactor.gt(0) 
            ? (wbtcHealthFactor.toNumber() / 1e18).toFixed(2) 
            : '--';
        
    } catch (error) {
        console.error('Failed to load portfolio data:', error);
    }
}

async function updatePrices() {
    if (!contracts.stableCoinEngine || !contracts.stablecoinWBTCEngine) return;
    
    try {
        const [ethPrice, btcPrice, exchangeRate] = await Promise.all([
            contracts.stableCoinEngine.getLatestPrice(),
            contracts.stablecoinWBTCEngine.getLatestPrice(),
            contracts.dex ? contracts.dex.getExchangeRate() : ethers.BigNumber.from(0)
        ]);
        
        document.getElementById('ethPrice').textContent = `$${(ethPrice.toNumber() / 1e8).toFixed(2)}`;
        document.getElementById('btcPrice').textContent = `$${(btcPrice.toNumber() / 1e8).toFixed(2)}`;
        
        if (exchangeRate.gt(0)) {
            document.getElementById('exchangeRate').textContent = `1 sBTC = ${ethers.utils.formatEther(exchangeRate)} sETH`;
            document.getElementById('footerExchangeRate').textContent = `1 sBTC = ${ethers.utils.formatEther(exchangeRate)} sETH`;
        }
        
    } catch (error) {
        console.error('Failed to update prices:', error);
    }
}

async function checkAndApprove(tokenContract, spender, amount) {
    const allowance = await tokenContract.allowance(userAddress, spender);
    if (allowance.lt(amount)) {
        const approveTx = await tokenContract.approve(spender, ethers.constants.MaxUint256);
        showNotification('Approving token spending. Please wait...', 'info');
        await approveTx.wait();
        showNotification('Token approval confirmed', 'success');
    }
}

function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: center;">
            <span>${message}</span>
            <button onclick="this.parentElement.parentElement.remove()" style="background: none; border: none; cursor: pointer; font-size: 1.2rem;">&times;</button>
        </div>
    `;
    
    document.getElementById('notifications').appendChild(notification);
    
    setTimeout(() => {
        if (notification.parentElement) {
            notification.remove();
        }
    }, 5000);
}

function showLoading(show) {
    document.getElementById('loadingOverlay').style.display = show ? 'flex' : 'none';
}

function resetAllData() {
    document.getElementById('fromBalance').textContent = '0.00';
    document.getElementById('toBalance').textContent = '0.00';
    document.getElementById('exchangeRate').textContent = 'Loading...';
    document.getElementById('ethPrice').textContent = 'Loading...';
    document.getElementById('btcPrice').textContent = 'Loading...';
    document.getElementById('footerExchangeRate').textContent = 'Loading...';
}

// Handle MetaMask events
if (typeof window.ethereum !== 'undefined') {
    window.ethereum.on('accountsChanged', (accounts) => {
        if (accounts.length === 0) {
            disconnectWallet();
        } else if (accounts[0] !== userAddress) {
            connectWallet();
        }
    });
    
    window.ethereum.on('chainChanged', (chainId) => {
        window.location.reload();
    });
}

console.log('🪙 StableCoin DEX Frontend Loaded');
console.log('Contract addresses:', CONTRACT_ADDRESSES);

// Helper functions for collateral calculations
async function calculateSETHCollateralRatio() {
    const wethAmount = document.getElementById('wethCollateral').value;
    const sethAmount = document.getElementById('sethToMint').value;
    const ratioElement = document.getElementById('sethCollateralRatio');
    
    if (!wethAmount || !sethAmount || !contracts.stableCoinEngine) {
        ratioElement.textContent = '---%';
        ratioElement.className = 'collateral-ratio';
        return;
    }
    
    try {
        const ethPrice = await contracts.stableCoinEngine.getLatestPrice();
        const collateralValue = ethers.utils.parseEther(wethAmount).mul(ethPrice).div(ethers.utils.parseEther('1'));
        const debtValue = ethers.utils.parseEther(sethAmount);
        
        const ratio = collateralValue.mul(100).div(debtValue);
        const ratioNumber = ratio.toNumber();
        
        ratioElement.textContent = `${ratioNumber}%`;
        
        // Color coding based on safety
        if (ratioNumber < 150) {
            ratioElement.style.color = '#ef4444'; // Red - unsafe
            ratioElement.textContent += ' ⚠️ Too Low';
        } else if (ratioNumber < 200) {
            ratioElement.style.color = '#f59e0b'; // Orange - risky
            ratioElement.textContent += ' ⚡ Risky';
        } else {
            ratioElement.style.color = '#10b981'; // Green - safe
            ratioElement.textContent += ' ✅ Safe';
        }
    } catch (error) {
        ratioElement.textContent = '---%';
        ratioElement.style.color = '#6b7280';
    }
}

async function calculateSBTCCollateralRatio() {
    const wbtcAmount = document.getElementById('wbtcCollateral').value;
    const sbtcAmount = document.getElementById('sbtcToMint').value;
    const ratioElement = document.getElementById('sbtcCollateralRatio');
    
    if (!wbtcAmount || !sbtcAmount || !contracts.stablecoinWBTCEngine) {
        ratioElement.textContent = '---%';
        ratioElement.className = 'collateral-ratio';
        return;
    }
    
    try {
        const btcPrice = await contracts.stablecoinWBTCEngine.getLatestPrice();
        const collateralValue = ethers.utils.parseUnits(wbtcAmount, 8).mul(btcPrice).div(ethers.utils.parseUnits('1', 8));
        const debtValue = ethers.utils.parseUnits(sbtcAmount, 8);
        
        const ratio = collateralValue.mul(100).div(debtValue);
        const ratioNumber = ratio.toNumber();
        
        ratioElement.textContent = `${ratioNumber}%`;
        
        // Color coding based on safety
        if (ratioNumber < 150) {
            ratioElement.style.color = '#ef4444'; // Red - unsafe
            ratioElement.textContent += ' ⚠️ Too Low';
        } else if (ratioNumber < 200) {
            ratioElement.style.color = '#f59e0b'; // Orange - risky
            ratioElement.textContent += ' ⚡ Risky';
        } else {
            ratioElement.style.color = '#10b981'; // Green - safe
            ratioElement.textContent += ' ✅ Safe';
        }
    } catch (error) {
        ratioElement.textContent = '---%';
        ratioElement.style.color = '#6b7280';
    }
}