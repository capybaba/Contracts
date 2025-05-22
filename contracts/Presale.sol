// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPancakeRouter.sol";
import "./libraries/PresaleMath.sol";
import "./libraries/PresaleUtils.sol";
import "./utils/TaxHandler.sol";
import "./utils/SafeTransfer.sol";
import "./events/PresaleEvents.sol";

/*
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMNkoxXMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMXxdkKNKx:,,dKxxXXkoooOWMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMKc,;,;:;,:oo:'cd:;,:::0MMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMWKc,;;:ll:;:cc;,,:;'c:,oO0NMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMXkl::clllllllllllllc.,:,.,lkNMMMMMMMMMMMMMM
MMMMMMMMMMMMMMW0d:,;::clllll:;;;;;:ll:;;:;,:okXMMMMMMMMMMMMM
MMMMMMMMMMMMNOo::;,'.,cllllc,;c;,;':lllll;;odoONMMMMMMMMMMMM
MMMMMMMMMMMKo:cllc::clllllllc::cc:cllllllc:;:lokXMMMMMMMMMMM
MMMMMMMMMWOlx0000Okdollllllllllllllllllllll;,ldd0MMMMMMMMMMM
MMMMMMMMM0clOXNN0k0X0dllllllllllllllllllccll::loONMMMMMMMMMM
MMMMMMMMXd;.;KN0:.l0xxdlllllllllllllllll:,:llc'':lOWMMMMMMMM
MMMMMMMMklkxkKNKocOKooxllllllllllllllllll:,::cc,:xXWMMMMMMMM
MMMMMMMMxoXN0d0NXXNXolxlllllllllllllllllll:,',:,.,kWMMMMMMMM
MMMMMMMMxoXNKddKNNNOcddllllllllllllllllllll;,,''':OWMMMMMMMM
MMMMMMMMKololl:cxxdodxollllllllllllllllllllc;;;.''oNMMMMMMMM
MMMMMMMMMN0kdlcoxdlc:;;;;;;;;:clllllllllllllccc,'''kWMMMMMMM
MMMMMMMMMMMMMWX000x;;ccccllllllllllllllllllllll:,,.cXMMMMMMM
MMMMMMMMMMMMMMMMMMNl;llllllllllllllllllllllllll::oloKMMMMMMM
MMMMMMMMMMMMMMMMMMMx;llllllllllllllllllllllllllc;kWWMMMMMMMM
MMMMMMMMMMMMMMMMMMMO:cllllllllllllllllllllllllll;xMMMMMMMMMM
MMMMMMMMMMMMMMMMMMM0::olllllllllllllllllllllllll;oNMMMMMMMMM
MMMMMMMMMMMMMMMMMMMXc:ollllllllllllllllllllllllo;lXMMMMMMMMM
MMMMMMMMMMMMMMMMMMMNo;lllllllllllllllllllllllllo:cXMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMx;lllllllllllllllllllllllllo:cXMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMk;cllllllllllllllllllllllllo:cXMMMMMMMMM
**/


contract Presale is Ownable, ReentrancyGuard {
    using PresaleMath for uint256;
    using TaxHandler for uint256;
    using SafeTransfer for address;
    using SafeTransfer for IERC20;

    IERC20 public presaleToken;
    IPancakeRouter public pancakeRouter;

    uint256 public startTime;
    uint256 public endTime;
    uint256 public softCap;
    uint256 public hardCap;
    uint256 public totalRaised;
    uint256 public totalSold;
    uint256 public presaleTokenAmount;
    uint256 public liquidityTokenAmount;
    uint256 public taxForRefundRate; // in basis points (e.g. 880 = 8.8%)
    address public taxRecipient;
    bool public liquidityAdded;
    uint256 public liquidityUnlockTime;
    bool public emergencyRefund;
    uint256 public liquidityPercent;
    uint256 public tokenPrice;
    uint256 public minBuyAmount;
    uint256 public maxBuyAmount;

    mapping(address => uint256) public contributions;

    modifier onlyWhileActive() {
        require(PresaleUtils.isPresaleActive(startTime, endTime, hardCap, totalRaised), "Presale not active");
        _;
    }

    constructor(
        address _token
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        presaleToken = IERC20(_token);
        pancakeRouter = IPancakeRouter(address(0));
        taxRecipient = msg.sender;
        presaleTokenAmount = 0;
        softCap = 0;
        hardCap = 0;
        taxForRefundRate = 0;
        startTime = 0;
        endTime = 0;
        liquidityPercent = 0;
        tokenPrice = 0;
    }

    /**
     * @notice Set all presale parameters and the presale token amount in one transaction.
     * @dev Can only be called by the owner before the presale starts and before any tokens are sold.
     * @param _softCap Minimum amount of BNB to raise (soft cap)
     * @param _hardCap Maximum amount of BNB to raise (hard cap, 0 for unlimited)
     * @param _taxForRefundRate Tax rate for refund (e.g. 5 for 5%)
     * @param _startTime Presale start timestamp
     * @param _durationDays Duration of presale in days
     * @param _liquidityPercent Percentage of raised BNB to add as liquidity
     * @param _tokenPrice Price per token (in wei)
     * @param _minBuyAmount Minimum BNB a user can contribute (per user, in wei)
     * @param _maxBuyAmount Maximum BNB a user can contribute (per user, in wei)
     */
    function setPresaleDetails(
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _taxForRefundRate,
        uint256 _startTime,
        uint256 _durationDays,
        uint256 _liquidityPercent,
        uint256 _tokenPrice,
        uint256 _minBuyAmount,
        uint256 _maxBuyAmount
    ) external onlyOwner nonReentrant {
        require(presaleTokenAmount == 0, "Presale token already set");
        require(totalRaised == 0 && totalSold == 0, "Presale already started");
        require(_hardCap == 0 || _hardCap > _softCap, "Hardcap must be zero or greater than softcap");
        require(_durationDays > 0, "Duration must be greater than zero");
        require(_liquidityPercent > 0 && _liquidityPercent <= 100, "Liquidity percent must be 1-100");
        require(_tokenPrice > 0, "Token price must be greater than zero");
        require(_maxBuyAmount == 0 || _maxBuyAmount > _minBuyAmount, "Max buy must be zero or greater than min buy");
        uint256 balance = presaleToken.balanceOf(address(this));
        require(balance > 0, "No tokens in contract");
        presaleTokenAmount = balance;
        softCap = _softCap;
        hardCap = _hardCap;
        taxForRefundRate = _taxForRefundRate;
        startTime = _startTime;
        endTime = PresaleUtils.calculateEndTime(_startTime, _durationDays);
        liquidityPercent = _liquidityPercent;
        tokenPrice = _tokenPrice;
        minBuyAmount = _minBuyAmount;
        maxBuyAmount = _maxBuyAmount;
        emit PresaleEvents.PresaleTokenDeposited(msg.sender, balance);
        emit PresaleEvents.PresaleDetailsSet(msg.sender, _softCap, _hardCap, _taxForRefundRate, _startTime, endTime, _liquidityPercent, _tokenPrice, _minBuyAmount, _maxBuyAmount);
    }

    /**
     * @notice Buy tokens directly via function call. No tax is applied.
     * @param beneficiary The address receiving the tokens
     */
    function buyTokens(address beneficiary) public payable nonReentrant {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
        require(PresaleUtils.isPresaleActive(startTime, endTime, hardCap, totalRaised), "Presale not active");
        require(msg.value > 0, "No BNB sent");
        if (hardCap != 0) {
            require(totalRaised + msg.value <= hardCap, "Hardcap reached");
        }
        uint256 tokensToBuy = PresaleMath.getTokenAmount(msg.value, tokenPrice);
        if (hardCap != 0) {
            require(totalSold + tokensToBuy <= presaleTokenAmount, "Not enough tokens left for presale");
        } else {
            require(totalSold + tokensToBuy <= (presaleTokenAmount * 60) / 100, "Not enough tokens left for presale");
        }
        _enforceBuyLimits(beneficiary, msg.value);
        presaleToken.safeTransferERC20(beneficiary, tokensToBuy);
        totalRaised += msg.value;
        totalSold += tokensToBuy;
        contributions[beneficiary] += msg.value;
        emit PresaleEvents.TokensPurchased(beneficiary, tokensToBuy, msg.value);
    }

    receive() external payable {
        buyTokensWithTax(msg.sender, msg.value);
    }

    /**
     * @notice Buy tokens via direct BNB transfer (receive). 0.8% tax is applied.
     * @param beneficiary The address receiving the tokens
     * @param value The amount of BNB sent
     */
    function buyTokensWithTax(address beneficiary, uint256 value) internal nonReentrant {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
        require(PresaleUtils.isPresaleActive(startTime, endTime, hardCap, totalRaised), "Presale not active");
        _enforceBuyLimits(beneficiary, value);
        require(value > 0, "No BNB sent");
        if (hardCap != 0) {
            require(totalRaised + value <= hardCap, "Hardcap reached");
        }
        uint256 tax = TaxHandler.calculateTax(value, 80); // 0.8% tax (80 basis points)
        uint256 netValue = value - tax;
        uint256 tokensToBuy = PresaleMath.getTokenAmount(netValue, tokenPrice);
        if (hardCap != 0) {
            require(totalSold + tokensToBuy <= presaleTokenAmount, "Not enough tokens left for presale");
        } else {
            require(totalSold + tokensToBuy <= (presaleTokenAmount * 60) / 100, "Not enough tokens left for presale");
        }
        if (tax > 0) {
            SafeTransfer.safeTransferBNB(taxRecipient, tax);
            emit PresaleEvents.TaxPaid(taxRecipient, tax);
        }
        presaleToken.safeTransferERC20(beneficiary, tokensToBuy);
        totalRaised += netValue;
        totalSold += tokensToBuy;
        contributions[beneficiary] += netValue;
        emit PresaleEvents.TokensPurchased(beneficiary, tokensToBuy, netValue);
    }

    function addLiquidity() external nonReentrant {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
        require(block.timestamp >= endTime, "Presale not ended");
        require(!liquidityAdded, "Liquidity already added");
        require(block.timestamp >= liquidityUnlockTime, "Liquidity unlock time not reached");
        require(totalRaised >= softCap, "Softcap not reached, cannot add liquidity");

        uint256 contractBalance = address(this).balance;
        uint256 bnbForLiquidity = (contractBalance * liquidityPercent) / 100;
        uint256 tokensForLiquidity = (totalSold * 80) / 100; // 40% of totalSold
        require(presaleToken.balanceOf(address(this)) >= tokensForLiquidity, "Not enough tokens for liquidity");

        presaleToken.approve(address(pancakeRouter), tokensForLiquidity);
        pancakeRouter.addLiquidityETH{value: bnbForLiquidity}(
            address(presaleToken),
            tokensForLiquidity,
            0,
            0,
            address(0xdEaD), // Send LP tokens to burn address
            block.timestamp + 600
        );
        liquidityAdded = true;
        emit PresaleEvents.LiquidityAdded(tokensForLiquidity, bnbForLiquidity);

        uint256 bnbForTaxRecipient = address(this).balance;
        if (bnbForTaxRecipient > 0) {
            SafeTransfer.safeTransferBNB(taxRecipient, bnbForTaxRecipient);
            emit PresaleEvents.TaxPaid(taxRecipient, bnbForTaxRecipient);
        }
    }

    /**
     * @notice Refund tokens during the presale period. User returns tokens to the contract and receives a BNB refund (tax applied).
     * @param tokenAmount Amount of tokens to refund
     */
    function refund(uint256 tokenAmount) external nonReentrant onlyWhileActive {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
        require(tokenAmount > 0, "Refund amount must be greater than zero");
        uint256 bnbToRefund = PresaleMath.getTokenAmount(tokenAmount, 1 ether) / tokenPrice;
        require(bnbToRefund > 0, "Refund value too small");
        require(address(this).balance >= bnbToRefund, "Insufficient BNB in contract");
        require(presaleToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        presaleTokenAmount += tokenAmount;
        totalSold -= tokenAmount;
        totalRaised -= bnbToRefund;
        contributions[msg.sender] -= bnbToRefund;
        uint256 tax = TaxHandler.calculateTax(bnbToRefund, taxForRefundRate);
        if (tax > 0) {
            SafeTransfer.safeTransferBNB(taxRecipient, tax);
            emit PresaleEvents.TaxPaid(taxRecipient, tax);
        }
        uint256 netRefund = bnbToRefund - tax;
        SafeTransfer.safeTransferBNB(msg.sender, netRefund);
    }

    function enableEmergencyRefund() external onlyOwner {
        require(!emergencyRefund, "Already enabled");
        emergencyRefund = true;
        emit PresaleEvents.EmergencyRefundEnabled();
    }

    function claimEmergencyRefund() external nonReentrant {
        require(emergencyRefund, "Emergency refund not enabled");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "No contribution to refund");
        uint256 tokensToReturn = PresaleMath.getTokenAmount(contributed, tokenPrice) / 1 ether;
        require(tokensToReturn > 0, "No tokens to return");
        require(presaleToken.transferFrom(msg.sender, address(this), tokensToReturn), "Token transfer failed");
        contributions[msg.sender] = 0;
        totalRaised -= contributed;
        totalSold -= tokensToReturn;
        SafeTransfer.safeTransferBNB(msg.sender, contributed);
        emit PresaleEvents.EmergencyRefundClaimed(msg.sender, contributed, tokensToReturn);
    }

    function isPresaleActive() public view returns (bool) {
        return PresaleUtils.isPresaleActive(startTime, endTime, hardCap, totalRaised);
    }

    function setPancakeRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router address");
        address oldRouter = address(pancakeRouter);
        pancakeRouter = IPancakeRouter(newRouter);
        emit PresaleEvents.PancakeRouterChanged(oldRouter, newRouter);
    }

    /**
     * @dev Internal function to enforce min/max buy limits per user (cumulative).
     * @param beneficiary The user address
     * @param newContribution The amount of BNB being contributed in this transaction
     */
    function _enforceBuyLimits(address beneficiary, uint256 newContribution) internal view {
        uint256 total = contributions[beneficiary] + newContribution;
        require(PresaleMath.isWithinBuyLimits(total, minBuyAmount, maxBuyAmount), "Buy amount out of allowed range");
    }
} 