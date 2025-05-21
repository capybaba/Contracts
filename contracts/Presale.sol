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
    bool public presaleEnded;
    bool public liquidityAdded;
    uint256 public liquidityUnlockTime;

    mapping(address => uint256) public contributions;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 value);
    event PresaleEnded(uint256 totalRaised, uint256 totalSold);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event Withdrawn(address indexed owner, uint256 amount);
    event TaxPaid(address indexed recipient, uint256 amount);

    modifier onlyWhileActive() {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Presale not active");
        require(!presaleEnded, "Presale ended");
        _;
    }

    constructor(
        address _token,
        address _router,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _presaleTokenAmount,
        uint256 _liquidityTokenAmount,
        uint256 _taxRate,
        address _taxRecipient,
        uint256 _startTime
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_router != address(0), "Invalid router address");
        require(_hardCap > _softCap, "Hardcap must be greater than softcap");
        require(_presaleTokenAmount > 0, "Presale token amount required");
        require(_liquidityTokenAmount > 0, "Liquidity token amount required");
        require(_taxRecipient != address(0), "Invalid tax recipient");
        presaleToken = IERC20(_token);
        pancakeRouter = IPancakeRouter(_router);
        softCap = _softCap;
        hardCap = _hardCap;
        presaleTokenAmount = _presaleTokenAmount;
        liquidityTokenAmount = _liquidityTokenAmount;
        taxRate = _taxRate;
        taxRecipient = _taxRecipient;
        startTime = _startTime;
        endTime = _startTime + 7 days;
        presaleEnded = false;
        liquidityAdded = false;
        uint256 totalRequired = _presaleTokenAmount + _liquidityTokenAmount;
        require(presaleToken.balanceOf(address(this)) >= totalRequired, "Insufficient tokens in presale contract");
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable nonReentrant onlyWhileActive {
        require(msg.value > 0, "No BNB sent");
        require(totalRaised + msg.value <= hardCap, "Hardcap reached");
        uint256 tokenPerBnb = presaleTokenAmount / hardCap;
        uint256 tokensToBuy = msg.value.getTokenAmount(tokenPerBnb);
        require(totalSold + tokensToBuy <= presaleTokenAmount, "Not enough tokens left for presale");
        uint256 netValue = msg.value;

        // Immediately transfer tokens to buyer
        require(presaleToken.transfer(beneficiary, tokensToBuy), "Token transfer failed");
        totalRaised += netValue;
        totalSold += tokensToBuy;
        contributions[beneficiary] += netValue;
        emit TokensPurchased(beneficiary, tokensToBuy, netValue);

        // End presale if hardcap is reached
        if (totalRaised >= hardCap) {
            _endPresale();
        }
    }

    function _endPresale() internal {
        presaleEnded = true;
        liquidityUnlockTime = block.timestamp + 1 days;
        emit PresaleEnded(totalRaised, totalSold);
    }

    function endPresale() external onlyOwner {
        require(!presaleEnded, "Already ended");
        require(block.timestamp >= endTime || totalRaised >= hardCap, "Cannot end yet");
        _endPresale();
    }

    function addLiquidity() external nonReentrant {
        require(presaleEnded, "Presale not ended");
        require(!liquidityAdded, "Liquidity already added");
        require(block.timestamp >= liquidityUnlockTime, "Liquidity unlock time not reached");
        require(totalRaised >= softCap, "Softcap not reached, cannot add liquidity");

        uint256 bnbForLiquidity = address(this).balance;
        uint256 tokensForLiquidity = liquidityTokenAmount;
        require(presaleToken.balanceOf(address(this)) >= tokensForLiquidity, "Not enough tokens for liquidity");

        // Add liquidity to PancakeSwap and send LP tokens to burn address
        presaleToken.approve(address(pancakeRouter), tokensForLiquidity);
        pancakeRouter.addLiquidityETH{value: bnbForLiquidity}(
            address(presaleToken),
            tokensForLiquidity,
            0,
            0,
            address(0xdead), // Send LP tokens to burn address
            block.timestamp + 600
        );
        liquidityAdded = true;
        emit LiquidityAdded(tokensForLiquidity, bnbForLiquidity);
    }


    /*
     * @dev only for test purpose
     * will be removed before deployment
     */
    function withdraw() external onlyOwner {
        require(presaleEnded, "Presale not ended");
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
        uint256 tokenPerBnb = presaleTokenAmount / hardCap;
        uint256 bnbToRefund = tokenAmount / tokenPerBnb;
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
} 