// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LoonyToken is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable
{    
    using SafeERC20 for IERC20;

    uint256 public sellLimit;
    uint256 public totalTaxPercentage;
    // uint256 public treasuryPercentage;
    // uint256 public donationPercentage;
    // uint256 public burnPercentage;

    address public donationWallet;
    address public treasuryWallet;
    // address public burnWallet;
    address public DEXPair;

    mapping(address => bool) public isExcludedFromTax;
    mapping(address => bool) public isDEXPair;

    event Initialized(address indexed owner, address donation, address treasury);

    address public adminWallet;
    uint256 public totalBurned;
    uint256 public constant MAX_BURN = 5_000_000 * 1e18;
    uint256 public constant QUARTERLY_BURN_AMOUNT = 625_000 * 1e18;

    uint256 public launchTime;
    uint256 public lastBurnTime;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _donationWallet,
        address _treasuryWallet
             
     ) public initializer {
        emit Initialized(msg.sender, _donationWallet, _treasuryWallet);
        __ERC20_init("LoonyToken", "$LOONY");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
       
        uint256 totalSupply = 1_000_000_000 * 1e18; // 1 billion
        _mint(msg.sender, totalSupply);

        donationWallet = _donationWallet;
        treasuryWallet = _treasuryWallet;

        totalTaxPercentage = 2;
        // treasuryPercentage = 1;
        // donationPercentage = 1;
        // burnPercentage = 1;
        sellLimit = 1000 * 1e18;
        launchTime = block.timestamp;
        adminWallet = msg.sender;

        require(_donationWallet != address(0), "Invalid donation wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        // require(_burnWallet !=address(0), "Invalid burn Wallet");
        
        isExcludedFromTax[msg.sender] = true;

    }

    function _update(address from, address to, uint256 amount) internal virtual override whenNotPaused {
    
    bool isBuy = isDEXPair[from];
    bool isSell = isDEXPair[to];

    if ((isBuy || isSell) && !isExcludedFromTax[from] && !isExcludedFromTax[to]) {

        uint256 totalTaxAmount = (amount * totalTaxPercentage) / 100;

        // Equal split
        uint256 halfTax = totalTaxAmount / 2;

        super._update(from, treasuryWallet, halfTax);     // 50% to treasury
        super._update(from, donationWallet, totalTaxAmount - halfTax); // 50% to donation 

        uint256 netAmount = amount - totalTaxAmount;
        super._update(from, to, netAmount); // send remaining to recipient

    } else {
        super._update(from, to, amount); // no tax
    }
}

    
    // Admin control functions
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    event QuarterlyBurn(uint256 timestamp, uint256 amount, uint256 totalBurned);

    function burnFromAdminWallet() external onlyOwner {
        require(block.timestamp >= launchTime + 365 days, "Burning not yet started");
        require(block.timestamp >= lastBurnTime + 90 days, "Quarter not reached");
        require(totalBurned < MAX_BURN, "Max burn completed");

        uint256 amountToBurn = QUARTERLY_BURN_AMOUNT;
        if (totalBurned + amountToBurn > MAX_BURN) {
            amountToBurn = MAX_BURN - totalBurned;
        }

        require(balanceOf(adminWallet) >= amountToBurn, "Insufficient tokens in admin wallet");

        _burn(adminWallet, amountToBurn);

        totalBurned += amountToBurn;
        lastBurnTime = block.timestamp;

        emit QuarterlyBurn(block.timestamp, amountToBurn, totalBurned);
    }

    function setAdminWallet(address newAdmin) external onlyOwner {
        require(newAdmin != address(0), "Zero address");
        adminWallet = newAdmin;
    }

    function totalBurnedTokens() external view returns (uint256) {
        return totalBurned / 1e18;
    }

    function setDEXPair(address pair, bool value) external onlyOwner {
        require(pair != address(0), "Zero address");
        isDEXPair[pair] = value;
    }

    function setTotalTaxPercentage(uint256 _newTax) external onlyOwner {
        require(_newTax <= 10, "Too high");
        totalTaxPercentage = _newTax;
    }

    // function setDonationTaxPercentage(uint256 _newDonationTax) external onlyOwner{
    //     require(_newDonationTax <= 10, "Too high");
    //     donationPercentage = _newDonationTax;
    // }

    // function setTreasuryTaxPercentage(uint256 _newTreasuryTax) external onlyOwner{
    //     require(_newTreasuryTax <=10, "Too high");
    //     treasuryPercentage = _newTreasuryTax;
    // }
    
    // function setBurnPercentage(uint256 _burn) external onlyOwner {
    //     require(_burn <= 10, "Too high");
    //     burnPercentage = _burn;
    // }

    function setSellLimit(uint256 newLimit) external onlyOwner {
        require(newLimit > 0, "Sell limit must be positive");
        sellLimit = newLimit;
    }

    function setTaxExclusion(address account, bool excluded) external onlyOwner {
        isExcludedFromTax[account] = excluded;
    }

    function updateWallets(
        address _donationWallet,
        address _treasuryWallet
        // address _burnWallet
    ) external onlyOwner {
        require(_donationWallet != address(0), "Invalid donation wallet");
        require(_treasuryWallet != address(0), "Invalid treasury wallet");
        // require(_burnWallet != address(0), "Invalid Burn Wallet");
        
        donationWallet = _donationWallet;
        treasuryWallet = _treasuryWallet;
        // burnWallet = _burnWallet;
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        require(token != address(this), "Cannot withdraw own tokens");
        IERC20(token).safeTransfer(owner(), amount);
    }

    // Required for UUPS upgradeability
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
