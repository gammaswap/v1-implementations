// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title An interface for a contract that is capable of deploying Uniswap V3 Pools
/// @notice A contract that constructs a pool must implement this to pass arguments to the pool
/// @dev This is used to avoid having constructor arguments in the pool contract, which results in the init code hash
/// of the pool being constant allowing the CREATE2 address of the pool to be cheaply computed on-chain
interface IGammaPoolFactory {
    struct Parameters {
        uint24 protocol;
        address[] tokens;
        address cfmm;
    }/**/

    function isProtocolRestricted(uint24 protocol) external view returns(bool);
    function setIsProtocolRestricted(uint24 protocol, bool isRestricted) external;
    function addModule(address module) external;
    function getModule(uint24 protocol) external view returns (address);
    function createPool(Parameters calldata params) external returns(address);
    function getPool(bytes32 salt) external view returns(address);
    function allPoolsLength() external view returns (uint);
    function feeTo() external view returns(address);
    function feeToSetter() external view returns(address);
    function owner() external view returns(address);
    function fee() external view returns(uint);

    /// @notice Get the parameters to be used in constructing the pool, set transiently during pool creation.
    /// @dev Called by the pool constructor to fetch the parameters of the pool
    /// Returns factory The factory address
    /// Returns tokens The token of the pool by address sort order
    /// Returns protocol The protocol id this pool is for (e.g. Uniswap, Sushiswap, etc.)
    /// Returns cfmm The address of the pool this is for (e.g. Uniswap, Sushiswap, etc.)
    function getParameters()
    external
    view
    returns (
        address[] memory tokens,
        uint24 protocol,
        address cfmm,
        address module
    );
}