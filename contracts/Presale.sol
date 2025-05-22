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
    event PresaleTokenDeposited(address indexed owner, uint256 amount);
    event PresaleDetailsSet(
        address indexed owner,
        uint256 softCap,
        uint256 hardCap,
        uint256 taxRate,
        uint256 startTime,
        uint256 endTime,
        uint256 liquidityPercent,
        uint256 tokenPrice
    );

    modifier onlyWhileActive() {
        require(block.timestamp >= startTime && block.timestamp < endTime, "Presale not active");
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
        taxRate = 0;
        startTime = 0;
        endTime = 0;
        liquidityPercent = 0;
        tokenPrice = 0;
    }

    function setPresaleDetails(
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _taxRate,
        uint256 _startTime,
        uint256 _durationDays,
        uint256 _liquidityPercent,
        uint256 _tokenPrice
    ) external onlyOwner nonReentrant {
        require(presaleTokenAmount == 0, "Presale token already set");
        require(totalRaised == 0 && totalSold == 0, "Presale already started");
        require(_hardCap == 0 || _hardCap > _softCap, "Hardcap must be zero or greater than softcap");
        require(_durationDays > 0, "Duration must be greater than zero");
        require(_liquidityPercent > 0 && _liquidityPercent <= 100, "Liquidity percent must be 1-100");
        require(_tokenPrice > 0, "Token price must be greater than zero");
        softCap = _softCap;
        hardCap = _hardCap;
        taxRate = _taxRate;
        startTime = _startTime;
        endTime = _startTime + (_durationDays * 1 days);
        liquidityPercent = _liquidityPercent;
        tokenPrice = _tokenPrice;
        emit PresaleDetailsSet(msg.sender, _softCap, _hardCap, _taxRate, _startTime, endTime, _liquidityPercent, _tokenPrice);
    }

    // Owner가 presaleToken을 입금하고 presaleTokenAmount를 설정하는 함수
    function setPresaleTokenAmount() external onlyOwner nonReentrant {
        require(presaleTokenAmount == 0, "Presale token amount already set");
        uint256 balance = presaleToken.balanceOf(address(this));
        require(balance > 0, "No tokens in contract");
        presaleTokenAmount = balance;
        emit PresaleTokenDeposited(msg.sender, balance);
    }

    receive() external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address beneficiary) public payable nonReentrant {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
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
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
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

    // Refund (sell) during presale period: user returns tokens to contract and receives BNB refund, 5% tax applied
    function refund(uint256 tokenAmount) external nonReentrant onlyWhileActive {
        require(presaleTokenAmount > 0, "Presale tokens not deposited");
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

    /**
     * @dev [TEST ONLY] Reset the presale contract.
     * - If liquidity was added, remove liquidity and send all tokens/BNB to owner.
     * - If not, just send all tokens/BNB to owner.
     * - Resets all fundraising and sale state variables.
     * - WARNING: This function is for testing only. REMOVE BEFORE DEPLOYMENT.
     * @param lpToken LP token (pair) address for this presale-token/BNB pair
     * @param lpAmount Amount of LP tokens to remove (should be full balance for full reset)
     * @param amountTokenMin Minimum amount of presaleToken to receive when removing liquidity
     * @param amountETHMin Minimum amount of BNB to receive when removing liquidity
     * @param deadline Deadline timestamp for removeLiquidityETH
     */
    function resetPresale(
        address lpToken,
        uint256 lpAmount,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        uint256 deadline
    ) external onlyOwner nonReentrant {
        // 1. If liquidity was added, remove liquidity and collect tokens/BNB
        if (liquidityAdded) {
            // Approve router to spend LP tokens
            IERC20(lpToken).approve(address(pancakeRouter), lpAmount);
            // Remove liquidity (presaleToken + BNB will be sent to this contract)
            pancakeRouter.removeLiquidityETH(
                address(presaleToken),
                lpAmount,
                amountTokenMin,
                amountETHMin,
                address(this),
                deadline
            );
        }
        // 2. Send all presaleToken to owner
        uint256 tokenBalance = presaleToken.balanceOf(address(this));
        if (tokenBalance > 0) {
            require(presaleToken.transfer(owner(), tokenBalance), "Token transfer failed");
        }
        // 3. Send all BNB to owner
        uint256 bnbBalance = address(this).balance;
        if (bnbBalance > 0) {
            (bool sent, ) = owner().call{value: bnbBalance}("");
            require(sent, "BNB transfer failed");
        }
        // 4. Reset fundraising and sale state variables
        totalRaised = 0;
        totalSold = 0;
        liquidityAdded = false;
        liquidityUnlockTime = 0;
        emergencyRefund = false;
        // Note: contributions mapping은 Solidity에서 전체 초기화 불가. 테스트에서는 별도 관리 필요.
        // liquidityPercent, tokenPrice, presaleTokenAmount 등은 설정값이므로 초기화하지 않음.
    }
} 

//
/*
    "tokenaddress",
    "0x87FD5305E6a40F378da124864B2D479c2028BD86",
    "10000000000000000000",
    "50000000000000000000",
    "8888888888888000000000000000000",
    "5",
    "0x3e41541075AAfe193258BCd494F8d447Db909386",
    "1747731600",
    "7",
    "90",
    "888888888000000000000000000"
**/