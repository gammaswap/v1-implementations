// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseBorrowStrategy.sol";
import "../../../strategies/deltaswap/liquidation/DSV2LiquidationStrategy.sol";

contract TestDSV2LiquidationStrategy is DSV2LiquidationStrategy, BaseBorrowStrategy {

    using LibStorage for LibStorage.Storage;
    using GSMath for uint;
    error ExcessiveBorrowing();

    event LoanCreated(address indexed caller, uint256 tokenId);

    constructor(address mathLib_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_,
        address feeSource_, uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) DSV2LiquidationStrategy(mathLib_,
        maxTotalApy_, blocksPerYear_, tradingFee1_, tradingFee2_, feeSource_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
    }

    function _calcOriginationFee(uint256 liquidityBorrowed, uint256 borrowedInvariant, uint256 lpInvariant, uint256 lowUtilRate, uint256 discount) internal virtual override view returns(uint256 origFee) {
        return originationFee();
        origFee = discount > origFee ? 0 : (origFee - discount);
    }

    function _calcDynamicOriginationFee(uint256 baseOrigFee, uint256 utilRate, uint256 lowUtilRate, uint256 minUtilRate1, uint256 minUtilRate2, uint256 feeDivisor) internal virtual override view returns(uint256) {
        return baseOrigFee;
    }

    function initialize(address factory_, address cfmm_, address[] calldata tokens_, uint8[] calldata decimals_, uint8 liquidationFee, uint8 ltvThreshold) external virtual {
        s.initialize(factory_, cfmm_, 1, tokens_, decimals_, 1e3);
        s.origFee = 0;
        s.liquidationFee = liquidationFee;
        s.ltvThreshold = ltvThreshold;
    }

    function cfmm() public view returns(address) {
        return s.cfmm;
    }

    function createLoan() external virtual returns(uint256 tokenId) {
        tokenId = s.createLoan(s.tokens.length, 0);
        emit LoanCreated(msg.sender, tokenId);
    }

    function getLoan(uint256 tokenId) external virtual view returns(LibStorage.Loan memory _loan) {
        _loan = s.loans[tokenId];
    }

    function getPoolData() external virtual view returns(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lpTokenBorrowedPlusInterest,
        uint128 borrowedInvariant, uint128 lpInvariant, uint128 lastCFMMInvariant, uint256 lastCFMMTotalSupply, uint128[] memory tokenBalance,
        uint48 lastBlockNumber, uint96 accFeeIndex) {
        lpTokenBalance = s.LP_TOKEN_BALANCE;
        lpTokenBorrowed = s.LP_TOKEN_BORROWED;
        lpTokenBorrowedPlusInterest = s.LP_TOKEN_BORROWED_PLUS_INTEREST;
        borrowedInvariant = s.BORROWED_INVARIANT;
        lpInvariant = s.LP_INVARIANT;
        lastCFMMInvariant = s.lastCFMMInvariant;
        lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        tokenBalance = s.TOKEN_BALANCE;
        lastBlockNumber = s.LAST_BLOCK_NUMBER;
        accFeeIndex = s.accFeeIndex;
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

    function depositLPTokens(uint256 tokenId) external virtual {
        // Update CFMM LP token amount tracked by GammaPool and invariant in CFMM belonging to GammaPool
        updateIndex();
        updateLoan(s.loans[tokenId]);
        updateCollateral(s.loans[tokenId]);
        uint256 lpTokenBalance = GammaSwapLibrary.balanceOf(s.cfmm, address(this));
        uint128 lpInvariant = uint128(convertLPToInvariant(lpTokenBalance, s.lastCFMMInvariant, s.lastCFMMTotalSupply));
        s.LP_TOKEN_BALANCE = lpTokenBalance;
        s.LP_INVARIANT = lpInvariant;
    }

    function calcBorrowRate(uint256, uint256, address, address) public override(AbstractRateModel, LinearKinkedRateModel) virtual view returns(uint256,uint256,uint256,uint256) {
        return (1e19,1e19,5000,1e18);
    }

    /// @dev See {BaseLongStrategy-getCurrentCFMMPrice}.
    function getCurrentCFMMPrice() internal virtual override view returns(uint256) {
        return s.CFMM_RESERVES[1] * (10 ** s.decimals[0]) / s.CFMM_RESERVES[0];
    }

    function mintOrigFeeToDevs(uint256 origFeeInv, uint256 totalInvariant) internal virtual override {
    }

    function _liquidateWithLP(uint256 tokenId) external override virtual returns(uint256 loanLiquidity, uint128[] memory refund) {
    }
}