// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "./Vesting.sol";


interface IERC20Extented is IERC20 {
    function decimals() external view returns (uint8);
}

contract CrowdSale is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public loonyToken;
    IERC20 public usdtToken;
    Vesting public vestingToken;

    uint256 public rate;
    uint256 public usdtRaised;
    uint256 public vestingMonths;
    uint256 public initialLockInPeriodInSeconds;

    uint256 public openingTime;
    uint256 public closingTime;
    bool public isFinalized;

    // Tax and Burn
    uint256 public totalTaxPercentage; // e.g. 300 = 3%
    // uint256 public treasuryPercentage; // e.g. 33 => 1% of 3%
    // uint256 public donationPercentage;
    // uint256 public burnPercentage;

    address public donationWallet;
    address public treasuryWallet;
    address public adminWallet;

    // Burn Plan
    uint256 public launchTime;
    uint256 public lastBurnTime;
    uint256 public totalBurned;
    uint256 public constant MAX_BURN = 5_000_000 * 1e18;
    uint256 public constant QUARTERLY_BURN_AMOUNT = 625_000 * 1e18;

    struct UserInfo {
        uint256 usdtContributed;
        uint256 LoonyReceived;
    }
    
    mapping(address => UserInfo) public users;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event TimedCrowdsaleExtended(uint256 prevClosingTime, uint256 newClosingTime);
    event Finalized();
    event WithdrawToken(address token, address to, uint256 amount);
    event TaxSettingsUpdated(uint256 totalTax);
    event WalletsUpdated(address treasury, address donation);
    event QuarterlyBurn(uint256 timestamp, uint256 amountBurned, uint256 totalBurned);

    modifier onlyWhileOpen() {
        require(block.timestamp >= openingTime && block.timestamp <= closingTime, "Crowdsale not active");
        _;
    }

    function initialize(
        uint256 _rate,
        IERC20 _token,
        IERC20 _usdtToken,
        uint256 _openingTime,
        uint256 _closingTime,
        Vesting _vesting
    ) public initializer {
        require(_rate > 0, "Rate must be > 0");
        require(_openingTime >= block.timestamp, "Opening time must be future");
        require(_closingTime >= _openingTime, "Closing time must be after opening");

        loonyToken = _token;
        usdtToken = _usdtToken;
        vestingToken = _vesting;
        rate = _rate;
        vestingMonths = 2;
        initialLockInPeriodInSeconds = 300;

        openingTime = _openingTime;
        closingTime = _closingTime;
        launchTime = block.timestamp;

        totalTaxPercentage = 300; // 3%
        // treasuryPercentage = 100;
        // donationPercentage = 100;
        // burnPercentage = 100;

        donationWallet = 0xD3Ab5b1c7EF2779F608796Cc7C692d40a229c66B;
        treasuryWallet = 0x5e6414507738265d6a93472d87d9E1ecb07E639C;
        adminWallet = msg.sender;

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init_unchained();
        __Pausable_init();
    }

    function buyToken(address _beneficiary, uint256 usdtAmount) external onlyWhileOpen whenNotPaused nonReentrant {
        require(_beneficiary != address(0), "Beneficiary can't be zero");
        require(usdtAmount > 0, "USDT amount must be > 0");

        usdtToken.safeTransferFrom(msg.sender, address(this), usdtAmount);

        uint256 tokens = _getTokenAmount(usdtAmount);

        // Calculate total tax amount from token amount (e.g., 3%)
        uint256 taxAmount = (tokens * totalTaxPercentage) / 10000;

        uint256 splitTax = taxAmount / 3;
        uint256 treasuryTax = splitTax;
        uint256 donationTax = splitTax;
        uint256 burnTax = taxAmount - (treasuryTax + donationTax); // ensures exact total

        // Calculate net tokens after tax
        uint256 netTokens = tokens - taxAmount;

        // Distribute tokens
        loonyToken.safeTransfer(treasuryWallet, treasuryTax);
        loonyToken.safeTransfer(donationWallet, donationTax);
        loonyToken.safeTransfer(address(0), burnTax); // burn tokens

        loonyToken.safeTransfer(address(vestingToken), netTokens);

        vestingToken.addTokenGrant(
            _beneficiary,
            netTokens,
            initialLockInPeriodInSeconds,
            vestingMonths
        );

        usdtRaised += usdtAmount;
        users[_beneficiary].usdtContributed += usdtAmount;
        users[_beneficiary].LoonyReceived += netTokens;

        emit TokenPurchase(msg.sender, _beneficiary, usdtAmount, netTokens);
         }

    // function buyToken(address _beneficiary, uint256 usdtAmount) external onlyWhileOpen whenNotPaused nonReentrant {
    //     require(_beneficiary != address(0), "Beneficiary can't be zero");
    //     require(usdtAmount > 0, "USDT amount must be > 0");

    //     usdtToken.safeTransferFrom(msg.sender, address(this), usdtAmount);

    //     uint256 tokens = _getTokenAmount(usdtAmount);
    //     uint256 taxAmount = (tokens * totalTaxPercentage) / 10000;

    //     uint256 treasuryTax = (taxAmount * treasuryPercentage) / 10000;
    //     uint256 donationTax = (taxAmount * donationPercentage) / 10000;
    //     uint256 burnTax = (taxAmount * burnPercentage) / 10000;

    //     uint256 netTokens = tokens - (treasuryTax + donationTax + burnTax);

    //     loonyToken.safeTransfer(treasuryWallet, treasuryTax);
    //     loonyToken.safeTransfer(donationWallet, donationTax);
    //     loonyToken.safeTransfer(address(0), burnTax);


    //     loonyToken.safeTransfer(address(vestingToken), netTokens);

    //     vestingToken.addTokenGrant(
    //         _beneficiary,
    //         netTokens,
    //         initialLockInPeriodInSeconds,
    //         vestingMonths
    //     );

    //     usdtRaised += usdtAmount;
    //     users[_beneficiary].usdtContributed += usdtAmount;
    //     users[_beneficiary].LoonyReceived += netTokens;

    //     emit TokenPurchase(msg.sender, _beneficiary, usdtAmount, netTokens);
    // }

    function _getTokenAmount(uint256 _usdtAmount) public view returns (uint256) {
        return (_usdtAmount * rate * 1e18) / 1e6;
    }

    function burnFromAdminWallet() external onlyOwner {
        require(block.timestamp >= launchTime + 365 days, "Burning not yet started");//started after 1 yr of launch tym
        require(block.timestamp >= lastBurnTime + 90 days, "Quarter not reached");
        require(totalBurned < MAX_BURN, "Max burn completed");

        uint256 amountToBurn = QUARTERLY_BURN_AMOUNT;
        if (totalBurned + amountToBurn > MAX_BURN) {
            amountToBurn = MAX_BURN - totalBurned;
        }

        require(loonyToken.balanceOf(adminWallet) >= amountToBurn, "Insufficient tokens in admin wallet");

        loonyToken.safeTransferFrom(adminWallet, address(0), amountToBurn);

        totalBurned += amountToBurn;
        lastBurnTime = block.timestamp;

        emit QuarterlyBurn(block.timestamp, amountToBurn, totalBurned);
        }

    function setTaxSettings(uint256 _totalTax) external onlyOwner {
        require(_totalTax <= 10000, "Total tax too high");

        totalTaxPercentage = _totalTax;
        // treasuryPercentage = _treasury;
        // donationPercentage = _donation;
        // burnPercentage = _burn;

        emit TaxSettingsUpdated(_totalTax);
    }

    function setWallets(address _treasury, address _donation ) external onlyOwner {
        require(_treasury != address(0) && _donation != address(0) , "Zero address");
        treasuryWallet = _treasury;
        donationWallet = _donation;
        emit WalletsUpdated(_treasury, _donation);
    }
    
    function extendSale(uint256 newClosingTime) external onlyOwner whenNotPaused {
        require(!isFinalized, "Already finalized");
        require(newClosingTime >= openingTime, "Invalid new time");
        require(newClosingTime > closingTime, "New time must be after current");

        emit TimedCrowdsaleExtended(closingTime, newClosingTime);
        closingTime = newClosingTime;
    }

    function finalize() external onlyOwner whenNotPaused {
        require(!isFinalized, "Already finalized");
        require(block.timestamp > closingTime, "Sale not closed yet");

        uint256 balance = loonyToken.balanceOf(address(this));
        require(balance > 0, "No tokens to finalize");

        loonyToken.safeTransfer(owner(), balance);

        emit Finalized();
        isFinalized = true;
    }

    function changeRate(uint256 newRate) external onlyOwner onlyWhileOpen whenNotPaused {
        require(newRate > 0, "Rate must be > 0");
        rate = newRate;
    }

    function changeInitialLockInPeriodInSeconds(uint256 newPeriod) external onlyOwner onlyWhileOpen whenNotPaused {
        require(newPeriod > 0, "Lock period must be > 0");
        initialLockInPeriodInSeconds = newPeriod;
    }

    function changeVestingInMonths(uint256 newVesting) external onlyOwner onlyWhileOpen whenNotPaused {
        require(newVesting > 0, "Vesting must be > 0");
        vestingMonths = newVesting;
    }

    function changeUsdtToken(IERC20Extented _newUsdt) external onlyOwner onlyWhileOpen whenNotPaused {
        require(_newUsdt.decimals() == 6, "USDT must have 6 decimals");
        usdtToken = _newUsdt;
    }

    function withdrawToken(address _tokenContract, uint256 _amount) external onlyOwner nonReentrant whenNotPaused {
        require(_tokenContract != address(0), "Token address can't be zero");
        IERC20(_tokenContract).safeTransfer(msg.sender, _amount);
        emit WithdrawToken(_tokenContract, msg.sender, _amount);
    }

    function withdrawUSDT(address _to, uint256 _amount) external onlyOwner nonReentrant whenNotPaused {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");
        require(usdtToken.balanceOf(address(this)) >= _amount, "Insufficient USDT balance in contract");

        usdtToken.safeTransfer(_to, _amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
