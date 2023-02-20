// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";

import "@gammaswap/v1-core/contracts/base/GammaPool.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/libraries/GammaSwapLibrary.sol";
import "../interfaces/external/balancer/IWeightedPool.sol";
import "../interfaces/external/balancer/IVault.sol";

/**
 * @title GammaPool implementation for Balancer Weighted Pool
 * @author JakeXBT (https://github.com/JakeXBT)
 * @dev This implementation is specifically for validating Balancer Weighted Pools
 * @notice implementation ID is unique to gammapool implementation
 */
contract BalancerGammaPool is GammaPool {

    error NotContract();
    error BadVaultAddress();
    error BadPoolId();
    error BadPoolAddress();
    error BadProtocol();
    error IncorrectTokenLength();
    error IncorrectTokens();
    error IncorrectWeights();
    error IncorrectPoolId();
    error IncorrectVaultAddress();
    error IncorrectSwapFee();

    using LibStorage for LibStorage.Storage;

    enum BalancerStorageVariables { WEIGHT0, POOLID }

    /// @return tokenCount - number of tokens expected in CFMM
    uint8 constant public tokenCount = 2;

    /**
     * @return poolFactory Address corresponding to the WeightedPoolFactory which created the Balancer weighted pool.
     */
    address immutable public poolFactory;

    /// @dev Stores weights passed to constructor as immutable variable
    uint256 immutable weight0;

    /// @dev Stores poolId passed to constructor as immutable variable
    bytes32 immutable poolId;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `balancerVault`, and `poolFactory`.
    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy, address _poolFactory, uint256 _weight0, bytes32 _poolId)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        poolFactory = _poolFactory;
        weight0 = _weight0;
        poolId = _poolId;
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount); // save gas using constant variable tokenCount
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata _data) external virtual override view returns(address[] memory _tokensOrdered, uint8[] memory _decimals) {
        // Decode the PoolId, Vault address, weight0 and swap fee from bytes calldata
        (bytes32 cfmmPoolId, address cfmmVault, uint256 cfmmWeight0, uint256 cfmmSwapFeePercentage) = abi.decode(_data, (bytes32, address, uint256, uint256));
        
        if(!GammaSwapLibrary.isContract(_cfmm)) { // Not a smart contract (hence not a CFMM) or not instantiated yet
            revert NotContract();
        }

        if(!IBasePoolFactory(poolFactory).isPoolFromFactory(_cfmm)) {
            revert BadProtocol();
        }

        // Order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // Fetch the tokens corresponding to the CFMM address
        bytes32 _poolId = IWeightedPool(_cfmm).getPoolId();
        address vault = IWeightedPool(_cfmm).getVault();
        uint256 swapFeePercentage = IWeightedPool(_cfmm).getSwapFeePercentage();
        uint256[] memory _weights = IWeightedPool(_cfmm).getNormalizedWeights();

        // Validate that all parameters match
        
        if (_poolId != cfmmPoolId) {
            revert IncorrectPoolId();
        }

        if (vault != cfmmVault) {
            revert IncorrectVaultAddress();
        }

        if (swapFeePercentage != cfmmSwapFeePercentage) {
            revert IncorrectSwapFee();
        }

        (IERC20[] memory vaultTokens, ,) = IVault(cfmmVault).getPoolTokens(cfmmPoolId);

        // Verify the number of tokens in the CFMM matches the number of tokens given in the constructor
        if(vaultTokens.length != tokenCount) {
            revert IncorrectTokenLength();
        }

        // Verify the tokens in the CFMM match the tokens given in the constructor
        if(_tokensOrdered[0] != address(vaultTokens[0]) || _tokensOrdered[1] != address(vaultTokens[1])) {
            revert IncorrectTokens();
        }

        if(_weights[0] != cfmmWeight0) {
            revert IncorrectWeights();
        }

        if(_weights[1] != 1e18 - cfmmWeight0) {
            revert IncorrectWeights();
        }

        // Get CFMM's tokens' decimals
        _decimals = new uint8[](2);
        _decimals[0] = GammaSwapLibrary.decimals(_tokensOrdered[0]);
        _decimals[1] = GammaSwapLibrary.decimals(_tokensOrdered[1]);
    }

}
