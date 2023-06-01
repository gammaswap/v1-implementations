// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@balancer-labs/v2-interfaces/contracts/pool-utils/IBasePoolFactory.sol";

import "@gammaswap/v1-core/contracts/base/GammaPool.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/libraries/GammaSwapLibrary.sol";
import "../strategies/balancer/BalancerBaseStrategy.sol";
import "../interfaces/external/balancer/IWeightedPool.sol";
import "../interfaces/external/balancer/IVault.sol";
import "../interfaces/strategies/IBalancerStrategy.sol";

/// @title GammaPool implementation for Balancer Weighted Pool
/// @dev This implementation is specifically for validating Balancer Weighted Pools
/// @notice Implementation ID is unique to gammapool implementation
contract BalancerGammaPool is GammaPool {

    error NotContract();
    error BadVaultAddress();
    error BadPoolId();
    error BadPoolAddress();
    error BadProtocol();
    error IncorrectVaultTokenLength();
    error IncorrectTokens();
    error IncorrectWeights();
    error IncorrectPoolId();
    error IncorrectVaultAddress();
    error IncorrectSwapFee();
    error InvalidTokensLength();

    using LibStorage for LibStorage.Storage;
    using FixedPoint for uint256;

    /// @return tokenCount - number of tokens expected in CFMM
    uint8 constant public tokenCount = 2;

    /// @return poolFactory Address corresponding to the WeightedPoolFactory which created the Balancer weighted pool.
    address immutable public poolFactory;

    /// @dev Stores weights passed to constructor as immutable variable
    uint256 immutable public weight0;

    /// @dev Stores weights passed to constructor as immutable variable
    uint256 immutable public weight1;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `balancerVault`, `poolFactory` and `weight0`.
    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy, address _poolFactory, uint256 _weight0)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        require(_weight0 == IBalancerStrategy(_longStrategy).weight0(), "weight0 long strategy");
        require(_weight0 == IBalancerStrategy(_shortStrategy).weight0(), "weight0 short strategy");
        require(_weight0 == IBalancerStrategy(_liquidationStrategy).weight0(), "weight0 liquidation strategy");
        
        poolFactory = _poolFactory;
        weight0 = _weight0;
        weight1 = 1e18 - weight0;
    }

    /// @dev Get poolId of Balancer CFMM in Vault
    function getPoolId() internal view virtual returns(bytes32) {
        return s.getBytes32(uint256(IBalancerStrategy.StorageIndexes.POOL_ID));
    }

    /// @dev Get vault address used for Balancer CFMM
    function getVault() internal view virtual returns(address) {
        return s.getAddress(uint256(IBalancerStrategy.StorageIndexes.VAULT));
    }

    /// @dev Get factors to scale tokens according to their decimals. Used to in Balancer invariant calculation
    function getScalingFactors() internal view virtual returns(uint256[] memory factors) {
        factors = new uint256[](2);
        factors[0] = s.getUint256(uint256(IBalancerStrategy.StorageIndexes.SCALING_FACTOR0));
        factors[1] = s.getUint256(uint256(IBalancerStrategy.StorageIndexes.SCALING_FACTOR1));
    }

    /// @dev See {GammaPoolERC4626.getLastCFMMPrice}.
    function _getLastCFMMPrice() internal virtual override view returns(uint256 lastPrice) {
        /*uint256[] memory factors = getScalingFactors();
        uint128[] memory reserves = _getLatestCFMMReserves();
        uint256 numerator = reserves[1] * factors[1] * weight1 / weight0;
        return numerator * 1e18 / (reserves[0] * factors[0]);/**/
    }

    /// @dev See {GammaPoolERC4626-_getLatestCFMMReserves}
    function _getLatestCFMMReserves() internal virtual override view returns(uint128[] memory cfmmReserves) {
        return IShortStrategy(shortStrategy)._getLatestCFMMReserves(
            abi.encode(IBalancerStrategy.BalancerReservesRequest({cfmmPoolId: getPoolId(), cfmmVault: getVault()})));
    }

    /// @dev See {GammaPoolERC4626-_getLatestCFMMInvariant}
    function _getLatestCFMMInvariant() internal virtual override view returns(uint256 lastCFMMInvariant) {
        return IShortStrategy(shortStrategy)._getLatestCFMMInvariant(
            abi.encode(IBalancerStrategy.BalancerInvariantRequest({cfmmPoolId: getPoolId(), cfmmVault: getVault(), scalingFactors: getScalingFactors()})));
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount); // save gas using constant variable tokenCount
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {GammaPoolERC4626._calcInvariant}.
    function _calcInvariant(uint128[] memory amounts) internal virtual override view returns(uint256) {
        uint256[] memory factors = getScalingFactors();
        uint256[] memory scaledReserves = new uint256[](2);
        scaledReserves[0] = amounts[0] * factors[0];
        scaledReserves[1] = amounts[1] * factors[1];
        return calcScaledInvariant(scaledReserves);
    }

    /// @dev Calculated invariant from amounts scaled to 18 decimals
    /// @param amounts - reserve amounts used to calculate invariant
    /// @return invariant - calculated invariant for Balancer AMM
    function calcScaledInvariant(uint256[] memory amounts) internal virtual view returns(uint256 invariant) {
        invariant = FixedPoint.ONE.mulDown(amounts[0].powDown(weight0)).mulDown(amounts[1].powDown(weight1));
    }

    /// @dev See {IGammaPool-initialize}
    function initialize(address _cfmm, address[] calldata _tokens, uint8[] calldata _decimals, bytes calldata _data) external virtual override {
        if(msg.sender != factory) revert Forbidden();// only factory is allowed to initialize

        s.initialize(factory, _cfmm, _tokens, _decimals);

        // Decode the PoolId in this function
        IBalancerStrategy.BalancerPoolData memory balancerPoolData = abi.decode(_data, (IBalancerStrategy.BalancerPoolData));

        // Store the PoolId in the storage contract
        s.setBytes32(uint256(IBalancerStrategy.StorageIndexes.POOL_ID), balancerPoolData.cfmmPoolId);

        // Store the Balancer Vault address in the storage contract
        s.setAddress(uint256(IBalancerStrategy.StorageIndexes.VAULT), balancerPoolData.cfmmVault);

        // Store the scaling factors for the CFMM in the storage contract
        s.setUint256(uint256(IBalancerStrategy.StorageIndexes.SCALING_FACTOR0), 10 ** (18 - _decimals[0]));
        s.setUint256(uint256(IBalancerStrategy.StorageIndexes.SCALING_FACTOR1), 10 ** (18 - _decimals[1]));
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata _data) external virtual override view returns(address[] memory _tokensOrdered) {
        IBalancerStrategy.BalancerPoolData memory balancerPoolData = abi.decode(_data, (IBalancerStrategy.BalancerPoolData));

        if(_tokens.length != tokenCount) revert InvalidTokensLength();
        if(!GammaSwapLibrary.isContract(_cfmm)) revert NotContract(); // Not a smart contract (hence not a CFMM) or not instantiated yet
        if(!IBasePoolFactory(poolFactory).isPoolFromFactory(_cfmm)) revert BadProtocol();

        // Order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // Fetch the tokens corresponding to the CFMM address
        bytes32 _poolId = IWeightedPool(_cfmm).getPoolId();
        address vault = IWeightedPool(_cfmm).getVault();
        uint256[] memory _weights = IWeightedPool(_cfmm).getNormalizedWeights();

        // Validate that all parameters match
        
        if (_poolId != balancerPoolData.cfmmPoolId) revert IncorrectPoolId();
        if (vault != balancerPoolData.cfmmVault) revert IncorrectVaultAddress();

        (IERC20[] memory vaultTokens, ,) = IVault(balancerPoolData.cfmmVault).getPoolTokens(balancerPoolData.cfmmPoolId);

        // Verify the number of tokens in the CFMM matches the number of tokens given in the constructor
        if(vaultTokens.length != tokenCount) revert IncorrectVaultTokenLength();

        // Verify the tokens in the CFMM match the tokens given in the constructor
        if(_tokensOrdered[0] != address(vaultTokens[0]) || _tokensOrdered[1] != address(vaultTokens[1])) {
            revert IncorrectTokens();
        }

        if(_weights[0] != balancerPoolData.cfmmWeight0 || _weights[0] != weight0) {
            revert IncorrectWeights();
        }
    }

    /// @dev See {IGammaPool-getRates}
    function getRates() external virtual override view returns(uint256, uint256, uint256) {
        return(0,0,0);
    }

    /// @dev See {IGammaPool-getPoolBalances}
    function getPoolBalances() external virtual override view returns(uint128[] memory tokenBalances, uint256 lpTokenBalance, uint256 lpTokenBorrowed,
        uint256 lpTokenBorrowedPlusInterest, uint256 borrowedInvariant, uint256 lpInvariant) {
        return(new uint128[](0), s.LP_TOKEN_BALANCE, 0, 0, 0, 0);
    }

    /// @dev See {IGammaPool-getLoans}
    function getLoans(uint256 start, uint256 end, bool active) external virtual override view returns(LoanData[] memory _loans) {
        _loans = new LoanData[](0);
    }

    /// @dev See {IGammaPool-getCFMMBalances}
    function getCFMMBalances() external virtual override view returns(uint128[] memory cfmmReserves, uint256 cfmmInvariant, uint256 cfmmTotalSupply) {
        return(new uint128[](0), s.lastCFMMInvariant, s.lastCFMMTotalSupply);
    }

    function calcDeltasForRatio(uint128[] memory tokensHeld, uint128[] memory reserves, uint256[] calldata ratio) external override virtual view returns(int256[] memory deltas) {
        deltas = new int256[](0);
    }
}
