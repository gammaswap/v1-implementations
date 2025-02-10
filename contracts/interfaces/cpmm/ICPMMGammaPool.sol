// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

/// @title Interface for Constant Product Market Maker version of GammaPool
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
interface ICPMMGammaPool {

    /// @dev _maxTotalAPY - new maximum total APY charged to Borrowers
    event SetMaxTotalAPY(uint256 _maxTotalAPY);

    /// @dev initialization parameters passed to CPMMGammaPool constructor
    struct InitializationParams {
        uint16 protocolId;
        address factory;
        address borrowStrategy;
        address repayStrategy;
        address rebalanceStrategy;
        address shortStrategy;
        address liquidationStrategy;
        address batchLiquidationStrategy;
        address viewer;
        address externalRebalanceStrategy;
        address externalLiquidationStrategy;
        address cfmmFactory;
        bytes32 cfmmInitCodeHash;
    }

    /// @dev set maximum total APY charged by GammaPool to borrowers
    /// @param _maxTotalAPY - new maximum total APY charged to GammaPool borrowers
    function setMaxTotalAPY(uint256 _maxTotalAPY) external;
}
