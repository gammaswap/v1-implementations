// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @title Interface for Rebalance Strategy of Constant Product Market Maker version of GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
interface ICPMMRebalanceStrategy {

    /// @dev _maxTotalAPY - new maximum total APY charged to Borrowers
    event SetMaxTotalAPY(uint256 _maxTotalAPY);

    /// @dev set maximum total APY charged by GammaPool to borrowers
    /// @param _maxTotalAPY - new maximum total APY charged to GammaPool borrowers
    function _setMaxTotalAPY(uint256 _maxTotalAPY) external;
}
