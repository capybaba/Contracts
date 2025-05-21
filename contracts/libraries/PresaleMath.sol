// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PresaleMath {
    // Calculate the number of tokens that can be bought
    function getTokenAmount(uint256 bnbAmount, uint256 tokenPerBnb) internal pure returns (uint256) {
        return bnbAmount * tokenPerBnb;
    }

    // Check if the cap (hardcap/softcap) is reached
    function isCapReached(uint256 raised, uint256 cap) internal pure returns (bool) {
        return raised >= cap;
    }
} 