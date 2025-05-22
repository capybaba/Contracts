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


interface IPancakeRouter {
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (
        uint amountToken,
        uint amountETH,
        uint liquidity
    );

    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
} 