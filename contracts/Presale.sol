// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IPancakeRouter.sol";
import "./libraries/PresaleMath.sol";
import "./utils/TaxHandler.sol";

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
    uint256 public taxRate; // 5 (for 5%)
    address public taxRecipient;
    bool public liquidityAdded;
    uint256 public liquidityUnlockTime;
    bool public emergencyRefund;
    uint256 public liquidityPercent;
    uint256 public tokenPrice;

    mapping(address => uint256) public contributions;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 value);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event Withdrawn(address indexed owner, uint256 amount);
    event TaxPaid(address indexed recipient, uint256 amount);
    event EmergencyRefundEnabled();
    event EmergencyRefundClaimed(address indexed user, uint256 bnbAmount, uint256 tokenAmount);
    event PancakeRouterChanged(address indexed oldRouter, address indexed newRouter);

    modifier onlyWhileActive() {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Presale not active");
        _;
    }

    constructor(
        address _token,
        address _router,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _presaleTokenAmount,
        uint256 _taxRate,
        address _taxRecipient,
        uint256 _startTime,
        uint256 _durationDays,
        uint256 _liquidityPercent,
        uint256 _tokenPrice
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_router != address(0), "Invalid router address");
        require(_hardCap == 0 || _hardCap > _softCap, "Hardcap must be zero or greater than softcap");
        require(_presaleTokenAmount > 0, "Presale token amount required");
        require(_taxRecipient != address(0), "Invalid tax recipient");
        require(_durationDays > 0, "Duration must be greater than zero");
        require(_liquidityPercent > 0 && _liquidityPercent <= 100, "Liquidity percent must be 1-100");
        require(_tokenPrice > 0, "Token price must be greater than zero");
        presaleToken = IERC20(_token);
        pancakeRouter = IPancakeRouter(_router);
        softCap = _softCap;
        hardCap = _hardCap;
        presaleTokenAmount = _presaleTokenAmount;
        taxRate = _taxRate;
        taxRecipient = _taxRecipient;
        startTime = _startTime;
        endTime = _startTime + (_durationDays * 1 days);
        liquidityPercent = _liquidityPercent;
        tokenPrice = _tokenPrice;
        uint256 totalRequired = _presaleTokenAmount;
        require(presaleToken.balanceOf(address(this)) >= totalRequired, "Insufficient tokens in presale contract");
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable nonReentrant {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Presale not active");
        require(msg.value > 0, "No BNB sent");
        if (hardCap != 0) {
            require(totalRaised + msg.value <= hardCap, "Hardcap reached");
        }
        uint256 tokensToBuy = (msg.value * tokenPrice) / 1 ether;
        if (hardCap != 0) {
            require(totalSold + tokensToBuy <= presaleTokenAmount, "Not enough tokens left for presale");
        } else {
            require(totalSold + tokensToBuy <= (presaleTokenAmount * 60) / 100, "Not enough tokens left for presale");
        }
        uint256 netValue = msg.value;

        // Immediately transfer tokens to buyer
        require(presaleToken.transfer(beneficiary, tokensToBuy), "Token transfer failed");
        totalRaised += netValue;
        totalSold += tokensToBuy;
        contributions[beneficiary] += netValue;
        emit TokensPurchased(beneficiary, tokensToBuy, netValue);
    }

    function addLiquidity() external nonReentrant {
        require(block.timestamp >= endTime, "Presale not ended");
        require(!liquidityAdded, "Liquidity already added");
        require(block.timestamp >= liquidityUnlockTime, "Liquidity unlock time not reached");
        require(totalRaised >= softCap, "Softcap not reached, cannot add liquidity");

        uint256 contractBalance = address(this).balance;
        uint256 bnbForLiquidity = (contractBalance * liquidityPercent) / 100;
        uint256 tokensForLiquidity = (totalSold * 80) / 100; // 40% of totalSold
        require(presaleToken.balanceOf(address(this)) >= tokensForLiquidity, "Not enough tokens for liquidity");

        // Add liquidity to PancakeSwap and send LP tokens to burn address
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
        emit LiquidityAdded(tokensForLiquidity, bnbForLiquidity);

        // Send the remaining BNB to taxRecipient
        uint256 bnbForTaxRecipient = address(this).balance;
        if (bnbForTaxRecipient > 0) {
            (bool sent, ) = taxRecipient.call{value: bnbForTaxRecipient}("");
            require(sent, "TaxRecipient transfer failed");
            emit TaxPaid(taxRecipient, bnbForTaxRecipient);
        }
    }


    /*
     * @dev only for test purpose
     * will be removed before deployment
     */
    function withdraw() external onlyOwner {
        require(block.timestamp >= endTime, "Presale not ended");
        uint256 balance = address(this).balance;
        require(balance > 0, "No BNB to withdraw");
        (bool sent, ) = owner().call{value: balance}("");
        require(sent, "Withdraw failed");
        emit Withdrawn(owner(), balance);
    }

    // Refund (sell) during presale period: user returns tokens to contract and receives BNB refund, 5% tax applied
    function refund(uint256 tokenAmount) external nonReentrant onlyWhileActive {
        require(tokenAmount > 0, "Refund amount must be greater than zero");
        // Calculate refund amount (same rate as purchase)
        uint256 bnbToRefund = (tokenAmount * 1 ether) / tokenPrice;
        require(bnbToRefund > 0, "Refund value too small");
        require(address(this).balance >= bnbToRefund, "Insufficient BNB in contract");

        // Transfer tokens from user to contract
        require(presaleToken.transferFrom(msg.sender, address(this), tokenAmount), "Token transfer failed");
        presaleTokenAmount += tokenAmount;
        totalSold -= tokenAmount;
        totalRaised -= bnbToRefund;
        contributions[msg.sender] -= bnbToRefund;

        // Calculate and send tax
        uint256 tax = bnbToRefund.calculateTax(taxRate);
        if (tax > 0) {
            (bool sentTax, ) = taxRecipient.call{value: tax}("");
            require(sentTax, "Tax transfer failed");
            emit TaxPaid(taxRecipient, tax);
        }
        uint256 netRefund = bnbToRefund - tax;

        // Refund user
        (bool sent, ) = msg.sender.call{value: netRefund}("");
        require(sent, "Refund failed");
    }

    function enableEmergencyRefund() external onlyOwner {
        require(!emergencyRefund, "Already enabled");
        emergencyRefund = true;
        emit EmergencyRefundEnabled();
    }

    function claimEmergencyRefund() external nonReentrant {
        require(emergencyRefund, "Emergency refund not enabled");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "No contribution to refund");
        uint256 tokensToReturn = (contributed * tokenPrice) / 1 ether;
        require(tokensToReturn > 0, "No tokens to return");
        require(presaleToken.transferFrom(msg.sender, address(this), tokensToReturn), "Token transfer failed");
        contributions[msg.sender] = 0;
        totalRaised -= contributed;
        totalSold -= tokensToReturn;
        (bool sent, ) = msg.sender.call{value: contributed}("");
        require(sent, "Refund failed");
        emit EmergencyRefundClaimed(msg.sender, contributed, tokensToReturn);
    }

    function isPresaleActive() public view returns (bool) {
        return block.timestamp >= startTime && block.timestamp < endTime;
    }

    function setPancakeRouter(address newRouter) external onlyOwner {
        require(newRouter != address(0), "Invalid router address");
        address oldRouter = address(pancakeRouter);
        pancakeRouter = IPancakeRouter(newRouter);
        emit PancakeRouterChanged(oldRouter, newRouter);
    }
} 