// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

//import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IGammaPool {//is IERC20 {

    function tokens() external view returns(address[] memory);
    function cfmm() external view returns(address);
    function mint(address to) external returns(uint);
    function burn(address to) external returns(uint[] memory);
    function loans(uint256 tokenId) external view returns (uint96 nonce, address operator, uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum);
    //function addLiquidity(uint[] calldata amountsDesired, uint[] calldata amountsMin, bytes calldata data) external returns(uint[] memory);
    function createLoan() external returns(uint tokenId);
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external returns(uint[] memory amounts);
    //function borrowMoreLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata collateralAmounts, bytes calldata data) external returns(uint[] memory amounts);
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts);
    function increaseCollateral(uint256 tokenId) external returns(uint[] memory tokensHeld);
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external returns(uint[] memory tokensHeld);
    function rebalanceCollateral(uint256 tokenId, uint256[] calldata posDeltas, uint256[] calldata negDeltas) external returns(uint[] memory tokensHeld);
    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external returns(uint[] memory tokensHeld);
}
