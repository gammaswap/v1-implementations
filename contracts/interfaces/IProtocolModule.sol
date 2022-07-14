// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocolModule {
    function protocol() external view returns(uint24);
    function protocolFactory() external view returns(address);
    function factory() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm)  external view returns(address[] memory tokens, bytes32 key);
    function getKey(address _cfmm) external view returns(bytes32);
    function getCFMMTotalInvariant(address cfmm) external view returns(uint256);
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external view returns(uint256);
    function addLiquidity(address cfmm, uint[] calldata amountsDesired, uint[] calldata amountsMin) external returns (uint[] memory amounts, address payee);
    function mint(address cfmm, uint[] calldata amounts) external returns(uint liquidity);
    function burn(address cfmm, address to, uint256 amount) external returns(uint[] memory amounts);
    function calcInvariant(address cfmm, uint[] calldata amounts) external view returns(uint invariant);
    function checkMaintenanceMargin(address cfmm, uint[] calldata tokensHeld, uint invariantBorrowed) external view returns(bool);
    function checkOpenMargin(address cfmm, uint[] calldata tokensHeld, uint invariantBorrowed) external view returns(bool);
    function getCFMMYield(address cfmm, uint256 prevInvariant, uint256 prevTotalSupply) external view returns(uint256 lastFeeIndex, uint256 lastInvariant, uint256 lastTotalSupply);
    function convertLiquidityToAmounts(address cfmm, uint256 liquidity) external view returns(uint256[] memory amounts);
    function rebalancePosition(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external returns(uint256[] memory _tokensHeld);
    function rebalancePosition(address cfmm, uint256[] calldata posDeltas, uint256[] calldata negDeltas, uint256[] calldata tokensHeld) external returns(uint256[] memory _tokensHeld);
    function repayLiquidity(address cfmm, uint256 liquidity, uint256[] calldata tokensHeld) external returns(uint256[] memory _tokensHeld, uint256[] memory _amounts, uint256 _lpTokens, uint256 _liquidity);
}
