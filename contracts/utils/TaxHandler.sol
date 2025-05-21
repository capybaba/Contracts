// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TaxHandler {
    // Calculate tax (e.g. 5%) 
    // only for refund
    function calculateTax(uint256 amount, uint256 taxRate) internal pure returns (uint256) {
        return (amount * taxRate) / 100;
    }
} 