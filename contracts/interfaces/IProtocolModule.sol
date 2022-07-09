// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IProtocolModule {
    function protocol() external view returns(uint24);
    function protocolFactory() external view returns(address);
    function factory() external view returns(address);
    function validateCFMM(address[] calldata _tokens, address _cfmm)  external view returns(address[] memory);
    function getKey(address _cfmm) external view returns(bytes32);
    function getCFMMTotalInvariant(address cfmm) external view returns(uint256);
    function getCFMMInvariantChanges(address cfmm, uint256 prevLPBal, uint256 curLPBal) external view returns(uint256, uint256);
    function addLiquidity(address cfmm, uint[] calldata amountsDesired, uint[] calldata amountsMin) external returns (uint[] memory);
    function getPayee(address cfmm) external view returns(address);
    function mint(address cfmm, uint[] calldata amounts) external returns(uint liquidity);
    function burn(address cfmm, address to) external returns(uint[] memory amounts);
}
