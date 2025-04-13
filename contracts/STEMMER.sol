// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // For USDT
import "@openzeppelin/contracts/access/Ownable.sol";

contract STEMMER is ERC20, Ownable {

    IERC20 public usdtToken;

    uint256 public buyRate = 1e18;      // Fixed: 1 USDT = 1 STEM
    uint256 public sellRate = 1e18;     // Dynamic: ≥ 1 STEM per USDT

    address public treasury;
    address public profitTreasury;

    // 🔧 NEW STATE VARIABLES
    uint256 public profitThreshold;
    uint256 public accumulatedProfit;

    // 📢 Events
    event BuyStem(address indexed buyer, uint256 usdtAmount, uint256 stemAmount);
    event SellStem(address indexed seller, uint256 stemAmount, uint256 usdtAmount, uint256 profitStems);
    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event SellRateUpdated(uint256 newSellRate);
    event BuyRateUpdated(uint256 newBuyRate);
    event TreasuryChanged(address indexed newTreasury);
    event ProfitTreasuryChanged(address indexed newProfitTreasury);
    event USDTWithdrawn(address indexed to, uint256 amount);
    event ProfitThresholdUpdated(uint256 newThreshold);
    event AccumulatedProfitWithdrawn(uint256 amount);

    constructor(
        address _usdtTokenAddress,
        address _treasury,
        address _profitTreasury,
        uint256 initialSupply,
        uint256 _profitThreshold
    ) ERC20("STEMMER", "STEM") Ownable(msg.sender) {
        usdtToken = IERC20(_usdtTokenAddress);
        treasury = _treasury;
        profitTreasury = _profitTreasury;
        profitThreshold = _profitThreshold;
        _mint(treasury, initialSupply * 1e18);
    }

    // 🔁 Buy STEM with USDT (always 1 USDT = 1 STEM)
    function buyStem(uint256 usdtAmount) external {
        require(usdtAmount > 0, "Amount must be greater than 0");

        uint256 stemAmount = usdtAmount * 1e18;
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");

        _transfer(treasury, msg.sender, stemAmount);
        emit BuyStem(msg.sender, usdtAmount, stemAmount);
    }

    // 🔁 Sell STEM for USDT
    function sellStem(uint256 stemAmount) external {
        require(stemAmount > 0, "Amount must be greater than 0");

        // Calculate USDT payout based on sellRate
        uint256 usdtAmount = (stemAmount * 1e18) / sellRate;

        // Calculate expected STEM if sellRate = 1.0
        uint256 fairUsdtAmount = stemAmount / 1e18;
        uint256 expectedStems = fairUsdtAmount * sellRate;
        uint256 profitStems = expectedStems > stemAmount ? expectedStems - stemAmount : 0;

        // Transfer user's STEMs to treasury
        _transfer(msg.sender, treasury, stemAmount);

        // 🔧 PROFIT HANDLING — BATCHED
        if (profitStems > 0 && profitTreasury != address(0)) {
            accumulatedProfit += profitStems;

            if (accumulatedProfit >= profitThreshold) {
                _transfer(treasury, profitTreasury, accumulatedProfit);
                accumulatedProfit = 0;
            }
        }

        require(usdtToken.transfer(msg.sender, usdtAmount), "USDT payout failed");
        emit SellStem(msg.sender, stemAmount, usdtAmount, profitStems);
    }

    // 🧠 Admin: Mint STEM
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount * 1e18);
        emit Minted(to, amount);
    }

    // 🧹 Admin: Burn STEM
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount * 1e18);
        emit Burned(from, amount);
    }

    // ⚙️ Admin: Change STEM buy rate
    function setBuyRate(uint256 newRate) external onlyOwner {
        require(newRate >= 1e18, "Buy rate must be >= 1 STEM");
        require(newRate <= sellRate, "Buy rate must be <= Sell rate");
        buyRate = newRate;
        emit BuyRateUpdated(newRate);
    }

    // ⚙️ Admin: Set Sell Rate
    function setSellRate(uint256 newRate) external onlyOwner {
        require(newRate >= 1e18, unicode"Sell rate must be ≥ 1 STEM per USDT");
        sellRate = newRate;
        emit SellRateUpdated(newRate);
    }

    // 🏦 Admin: Withdraw USDT
    function withdrawUSDT(address to, uint256 amount) external onlyOwner {
        require(usdtToken.transfer(to, amount), "Withdraw failed");
        emit USDTWithdrawn(to, amount);
    }

    // 🏦 Admin: Set main treasury
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
        emit TreasuryChanged(_treasury);
    }

    // 🏦 Admin: Set profit wallet
    function setProfitTreasury(address _treasury) external onlyOwner {
        profitTreasury = _treasury;
        emit ProfitTreasuryChanged(_treasury);
    }

    // 🔧 NEW: Set profit threshold
    function setProfitThreshold(uint256 newThreshold) external onlyOwner {
        require(newThreshold > 0, "Threshold must be > 0");
        profitThreshold = newThreshold;
        emit ProfitThresholdUpdated(newThreshold);
    }

    // 🔧 NEW: Withdraw any accumulated profit manually
    function withdrawAccumulatedProfit() external onlyOwner {
        require(accumulatedProfit > 0, "No profit to withdraw");
        _transfer(treasury, profitTreasury, accumulatedProfit);
        emit AccumulatedProfitWithdrawn(accumulatedProfit);
        accumulatedProfit = 0;
    }

    // Optional frontend helper
    function getConfig() external view returns (
        uint256 _buyRate,
        uint256 _sellRate,
        address _treasury,
        address _profitTreasury,
        uint256 treasuryStemBalance,
        uint256 profitStemBalance,
        uint256 contractStemBalance,
        uint256 contractUsdtBalance,
        uint256 totalStemSupply,
        uint256 _accumulatedProfit,
        uint256 _profitThreshold
    ) {
        return (
            buyRate,
            sellRate,
            treasury,
            profitTreasury,
            balanceOf(treasury),
            balanceOf(profitTreasury),
            balanceOf(address(this)),
            usdtToken.balanceOf(address(this)),
            totalSupply(),
            accumulatedProfit,
            profitThreshold
        );
    }
}
