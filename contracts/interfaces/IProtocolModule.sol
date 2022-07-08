// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocolModule {
    function protocol() external view returns(uint24);
    function protocolFactory() external view returns(address);
    function factory() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm)  external view returns(address[] memory tokens);
    function getKey(address _cfmm) external view returns(bytes32 key);
    function getCFMM(address tokenA, address tokenB) external view returns(address cfmm);
    function getCFMMInvariantChanges(address cfmm, uint256 lpTokenBal) external pure returns(uint256 totalInvariantInCFMM, uint256 depositedInvariant);
    function addLiquidity(
        address gammaPool,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin,
        address payer
    ) external returns (uint[] memory amounts);
}
