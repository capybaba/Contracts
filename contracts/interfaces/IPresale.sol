// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    function isActive() external view returns (bool);

    // Claim purchased tokens
    function claimTokens() external;

    // Owner function: withdraw funds, etc.
    function withdraw() external;

    // Refund (sell) during presale period
    function refund(uint256 tokenAmount) external;

    // Event: Token purchase
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 value);

    // Event: Token claim
    event TokensClaimed(address indexed claimer, uint256 amount);

    // Event: Owner withdrawal
    event Withdrawn(address indexed owner, uint256 amount);

    // Event: Refund (sell)
    event Refunded(address indexed user, uint256 tokenAmount, uint256 bnbAmount);
} 