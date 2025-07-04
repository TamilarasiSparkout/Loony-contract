// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV2Router {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract LoonyToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    uint256 public taxPercentage; // 2 = 2%
    address public donationWallet;
    address public treasuryWallet;

    address public router;
    address public dexPair;
    bool public  isLiquidityEnabled;

    mapping(address => bool) public isExcludedFromTax;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _router,
        address _donationWallet,
        address _treasuryWallet
    ) public initializer {
        __ERC20_init("LoonyToken", "$LOONY");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();

        require(_router != address(0), "Router address is zero");
        require(_donationWallet != address(0), "Invalid donation wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");

        uint256 totalSupply = 1_000_000_000 * 1e18;
        _mint(msg.sender, totalSupply);

        router = _router;
        donationWallet = _donationWallet;
        treasuryWallet = _treasuryWallet;
        taxPercentage = 2;

        IUniswapV2Router uniRouter = IUniswapV2Router(router);
        dexPair = IUniswapV2Factory(uniRouter.factory()).createPair(address(this), uniRouter.WETH());

        isExcludedFromTax[msg.sender] = true;
        isLiquidityEnabled = false;
        // isExcludedFromTax[address(this)] = true;

    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function _update(address from, address to, uint256 amount) internal override whenNotPaused {
        bool isBuy = from == dexPair;
        bool isSell = to == dexPair;
 
    // Skip tax for owner (for liquidity operations) or if sender/recipient is excluded
        if ( isLiquidityEnabled || isExcludedFromTax[from] || isExcludedFromTax[to] ) {
            super._update(from, to, amount);
            return;
        }
 
    // Apply tax only for buy/sell on DEX
        if (isBuy || isSell) {
            uint256 taxAmount = (amount * taxPercentage) / 100;
            uint256 netAmount = amount - taxAmount;

            uint256 halfTax = taxAmount / 2;
            uint256 remaining = taxAmount - halfTax;

        // Send tax to wallets
            super._update(from, donationWallet, halfTax);
            super._update(from, treasuryWallet, remaining);

        // Transfer remaining to receiver
            super._update(from, to, netAmount);
        } else {
            super._update(from, to, amount);
    }
}
  
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    // Owner Functions
    function setTaxPercentage(uint256 _percent) external onlyOwner {
        require(_percent <= 10, "Too high");
        taxPercentage = _percent;
    }

    function setWallets(address _donation, address _treasury) external onlyOwner {
        require(_donation != address(0) && _treasury != address(0), "Invalid address");
        donationWallet = _donation;
        treasuryWallet = _treasury;
    }

    function excludeFromTax(address addr, bool excluded) external onlyOwner {
        isExcludedFromTax[addr] = excluded;
    }

    // Pause
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

}
