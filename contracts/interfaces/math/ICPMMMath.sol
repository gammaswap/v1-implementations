pragma solidity ^0.8.0;

interface ICPMMMath {

    function calcDeltasToClose(uint256 lastCFMMInvariant, uint256 reserve, uint256 collateral, uint256 liquidity) external pure returns(int256 delta);

    function calcDeltasForRatio(uint256 ratio, uint128 reserve0, uint128 reserve1, uint128[] memory tokensHeld, uint256 factor, bool side, uint256 fee1, uint256 fee2) external pure returns(int256[] memory deltas);
}
