// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


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

interface IPresale {
    // Buy tokens (with ETH or specified token)
    function buyTokens(address beneficiary) external payable;

    // Presale start/end time
    function startTime() external view returns (uint256);
    function endTime() external view returns (uint256);

    // Total tokens sold and total funds raised
    function totalSold() external view returns (uint256);
    function totalRaised() external view returns (uint256);

    // Presale active status
    function isPresaleActive() external view returns (bool);

    // Owner function: withdraw funds
    function withdraw() external;

    // Refund (sell) during presale period
    function refund(uint256 tokenAmount) external;

    // Liquidity
    function addLiquidity() external;
    function liquidityAdded() external view returns (bool);
    function liquidityPercent() external view returns (uint256);

    // Tax recipient
    function taxRecipient() external view returns (address);

    // Emergency refund
    function enableEmergencyRefund() external;
    function claimEmergencyRefund() external;
    function emergencyRefund() external view returns (bool);

    // Token price
    function tokenPrice() external view returns (uint256);

    // Events
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 value);
    event LiquidityAdded(uint256 tokenAmount, uint256 bnbAmount);
    event Withdrawn(address indexed owner, uint256 amount);
    event TaxPaid(address indexed recipient, uint256 amount);
    event EmergencyRefundEnabled();
    event EmergencyRefundClaimed(address indexed user, uint256 bnbAmount, uint256 tokenAmount);
} 