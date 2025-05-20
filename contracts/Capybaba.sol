// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Capybaba is ERC20 {
    constructor() ERC20("Capybaba", "CPBB") {
        _mint(msg.sender, 8_888_888_888_888 * 10 ** decimals());
    }
} 