// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../strategies/balancer/external/BalancerExternalLongStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestBalancerLongStrategy is BalancerExternalLongStrategy {

    using LibStorage for LibStorage.Storage;
    using Math for uint;

    event LoanCreated(address indexed caller, uint256 tokenId);
    event ActualOutAmount(uint256 outAmount);
    event CalcAmounts(uint256[] outAmts, uint256[] inAmts);

    constructor(uint16 _originationFee, uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerExternalLongStrategy(10, 8000, 1e19, 2252571, _originationFee, _baseRate, _factor, _maxApy, _weight0) {
    }

    function initialize(address _cfmm, address[] calldata tokens, uint8[] calldata decimals, bytes32 _poolId, address _vault) external virtual {
        s.initialize(msg.sender, _cfmm, tokens, decimals);

        // Store the PoolId in the storage contract
        s.setBytes32(uint256(StorageIndexes.POOL_ID), _poolId);

        s.setAddress(uint256(StorageIndexes.VAULT), _vault);

        // Store the scaling factors for the CFMM in the storage contract
        s.setUint256(uint256(StorageIndexes.SCALING_FACTOR0), 10 ** (18 - decimals[0]));
        s.setUint256(uint256(StorageIndexes.SCALING_FACTOR1), 10 ** (18 - decimals[1]));
    }
    
    function getCFMM() public virtual view returns(address) {
        return s.cfmm;
    }

    function getCFMMReserves() public virtual view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }

    function testGetPoolId(address) public virtual view returns(bytes32) {
        return getPoolId();
    }

    function testGetVault(address) public virtual view returns(address) {
        return getVault();
    }

    function testGetPoolReserves(address) public view returns(uint256[] memory _reserves) {
        (,_reserves,) = IVault(getVault()).getPoolTokens(getPoolId());
    }

    function testGetWeights() public virtual view returns(uint256[] memory _weights) {
        _weights = new uint256[](2);
        _weights[0] = weight0;
        _weights[1] = weight1;
    }

    function testGetTokens(address) public virtual view returns(address[] memory) {
        return s.tokens;
    }

    function cfmm() public view returns(address) {
        return s.cfmm;
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length);
        emit LoanCreated(msg.sender, tokenId);
    }

    function setTokenBalances(uint256 tokenId, uint128 collateral0, uint128 collateral1, uint128 balance0, uint128 balance1) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        loan.tokensHeld[0] = collateral0;
        loan.tokensHeld[1] = collateral1;
        s.TOKEN_BALANCE[0] = balance0;
        s.TOKEN_BALANCE[1] = balance1;
    }

    function setCFMMReserves(uint128 reserve0, uint128 reserve1, uint128 lastCFMMInvariant) external virtual {
        s.CFMM_RESERVES[0] = reserve0;
        s.CFMM_RESERVES[1] = reserve1;
        s.lastCFMMInvariant = lastCFMMInvariant;
    }

    function testCalcTokensToRepay(uint256 liquidity) external virtual view returns(uint256, uint256) {
        uint256[] memory amounts;
        amounts = calcTokensToRepay(liquidity);
        return(amounts[0], amounts[1]);
    }

    function testBeforeRepay(uint256 tokenId, uint256[] memory amounts) external virtual {
        beforeRepay(s.loans[tokenId], amounts);
    }

    // Calculating how much input required for a given output amount
    function testGetAmountIn(uint256 amountOut, uint256 reserveOut, uint256 weightOut, uint256 reserveIn, uint256 weightIn, uint256 scalingFactorIn, uint256 scalingFactorOut, bool flipWeights) external virtual view returns (uint256) {
        uint128[] memory reserves = new uint128[](2);
        reserves[0] = uint128(reserveOut);
        reserves[1] = uint128(reserveIn);
        uint256[] memory weights = new uint256[](2);
        weights[0] = weightOut;
        weights[1] = weightIn;
        uint256[] memory scalingFactors = new uint256[](2);
        scalingFactors[0] = scalingFactorIn;
        scalingFactors[1] = scalingFactorOut;
        return getAmountIn(amountOut, uint128(reserveOut), uint128(reserveIn), weightOut, weightIn, scalingFactorIn, scalingFactorOut, flipWeights);
    }

    // Calculating how much output required for a given input amount
    function testGetAmountOut(uint256 amountIn, uint256 reserveOut, uint256 weightOut, uint256 reserveIn, uint256 weightIn, uint256 scalingFactorIn, uint256 scalingFactorOut, bool flipWeights) external virtual view returns (uint256) {
        uint128[] memory reserves = new uint128[](2);
        reserves[0] = uint128(reserveOut);
        reserves[1] = uint128(reserveIn);
        uint256[] memory weights = new uint256[](2);
        weights[0] = weightOut;
        weights[1] = weightIn;
        uint256[] memory scalingFactors = new uint256[](2);
        scalingFactors[0] = scalingFactorIn;
        scalingFactors[1] = scalingFactorOut;
        return getAmountOut(amountIn, uint128(reserveOut), uint128(reserveIn), weightOut, weightIn, scalingFactorIn, scalingFactorOut, flipWeights);
    }

    function testBeforeSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (outAmts, inAmts) = beforeSwapTokens(loan, deltas);
        emit CalcAmounts(outAmts, inAmts);
    }

    function testSwapTokens(uint256 tokenId, int256[] calldata deltas) external virtual {
        LibStorage.Loan storage loan = s.loans[tokenId];
        (uint256[] memory outAmts, uint256[] memory inAmts) = beforeSwapTokens(loan, deltas);
        swapTokens(loan, outAmts, inAmts);
        emit CalcAmounts(outAmts, inAmts);
    }

    function _borrowLiquidity(uint256, uint256) external virtual override(ILongStrategy, LongStrategy) returns(uint256, uint256[] memory) {
        return (0, new uint256[](2));
    }

    function _repayLiquidity(uint256, uint256, uint256[] calldata) external virtual override(ILongStrategy, LongStrategy) returns(uint256, uint256[] memory) {
        return (0, new uint256[](2));
    }

    function _decreaseCollateral(uint256, uint256[] calldata, address) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _increaseCollateral(uint256) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }

    function _rebalanceCollateral(uint256, int256[] calldata) external virtual override(ILongStrategy, LongStrategy) returns(uint128[] memory) {
        return new uint128[](2);
    }
}
