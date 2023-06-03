// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/strategies/BaseLongStrategy.sol";
import "./CPMMBaseStrategy.sol";
import "../../interfaces/math/ICPMMMath.sol";

/// @title Base Long Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for CPMM that need access to loans
/// @dev This implementation was specifically designed to work with UniswapV2.
abstract contract CPMMBaseLongStrategy is BaseLongStrategy, CPMMBaseStrategy {

    error BadDelta();
    error ZeroReserves();
    error CollateralIdGte2();

    /// @return LTV_THRESHOLD - max ltv ratio acceptable before a loan is eligible for liquidation
    uint16 immutable public LTV_THRESHOLD;

    /// @return origFee - origination fee charged to every new loan that is issued
    uint24 immutable public origFee;

    /// @return tradingFee1 - numerator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2)
    uint16 immutable public tradingFee1;

    /// @return tradingFee2 - denominator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2)
    uint16 immutable public tradingFee2;

    /// @return mathLib - contract containing complex mathematical functions
    address immutable public mathLib;

    /// @return Returns the minimum liquidity borrowed amount.
    uint256 constant public MIN_BORROW = 1e3;

    /// @dev Initializes the contract by setting `mathLib`, `LTV_THRESHOLD`, `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`,
    /// @dev `origFee`, `tradingFee1`, `tradingFee2`, `baseRate`, `factor`, and `maxApy`
    constructor(address mathLib_, uint16 ltvThreshold_, uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 origFee_,
        uint16 tradingFee1_, uint16 tradingFee2_, uint64 baseRate_, uint80 factor_, uint80 maxApy_)
        CPMMBaseStrategy(maxTotalApy_, blocksPerYear_, baseRate_, factor_, maxApy_) {

        mathLib = mathLib_;
        LTV_THRESHOLD = ltvThreshold_;
        origFee = origFee_;
        tradingFee1 = tradingFee1_;
        tradingFee2 = tradingFee2_;
    }

    /// @return Returns the minimum liquidity borrowed amount.
    function minBorrow() internal virtual override view returns(uint256) {
        return MIN_BORROW;
    }

    /// @dev See {BaseLongStrategy-_ltvThreshold}.
    function _ltvThreshold() internal virtual override view returns(uint16) {
        return LTV_THRESHOLD;
    }

    /// @dev See {BaseLongStrategy-originationFee}.
    function originationFee() internal virtual override view returns(uint24) {
        return origFee;
    }

    /// @dev See {BaseLongStrategy-_calcDeltasToClose}.
    function _calcDeltasToClose(uint128[] memory tokensHeld, uint128[] memory reserves, uint256 liquidity, uint256 collateralId)
        internal virtual override view returns(int256[] memory deltas) {

        if(collateralId >= 2) revert CollateralIdGte2();

        deltas = new int256[](2);

        (bool success, bytes memory data) = mathLib.staticcall(abi.encodeWithSelector(ICPMMMath(mathLib).
            calcDeltasToClose.selector, calcInvariant(address(0), reserves), reserves[collateralId],
            tokensHeld[collateralId], liquidity));
        require(success && data.length >= 1);

        deltas[collateralId] = abi.decode(data, (int256));
    }

    /// @dev See {BaseLongStrategy-calcTokensToRepay}.
    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity) internal virtual override view
        returns(uint256[] memory amounts) {

        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = calcInvariant(address(0), reserves);
        amounts[0] = liquidity * reserves[0] / lastCFMMInvariant;
        amounts[1] = liquidity * reserves[1] / lastCFMMInvariant;
    }

    /// @dev See {BaseLongStrategy-beforeRepay}.
    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory _amounts) internal virtual override {
        address[] memory tokens = s.tokens;
        address cfmm = s.cfmm;
        if(_amounts[0] > 0) sendToken(tokens[0], cfmm, _amounts[0], s.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
        if(_amounts[1] > 0) sendToken(tokens[1], cfmm, _amounts[1], s.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
    }

    /// @dev See {BaseLongStrategy-swapTokens}.
    function swapTokens(LibStorage.Loan storage, uint256[] memory, uint256[] memory inAmts) internal virtual override {
        ICPMM(s.cfmm).swap(inAmts[0],inAmts[1],address(this),new bytes(0)); // out amounts already sent in beforeSwapTokens
    }

    /// @dev See {BaseLongStrategy-swapTokens}.
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves)
        internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {

        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(_loan, reserves[0], reserves[1],
            deltas[0], deltas[1]);
    }

    /// @dev Calculate expected bought and sold amounts given reserves in CFMM
    /// @param _loan - liquidity loan whose collateral will be used to calculates swap amounts
    /// @param reserve0 - amount of token0 in CFMM
    /// @param reserve1 - amount of token1 in CFMM
    /// @param delta0 - desired amount of collateral token0 from loan to swap (> 0 buy, < 0 sell, 0 ignore)
    /// @param delta1 - desired amount of collateral token1 from loan to swap (> 0 buy, < 0 sell, 0 ignore)
    /// @return inAmt0 - expected amount of token0 to receive from CFMM (buy)
    /// @return inAmt1 - expected amount of token1 to receive from CFMM (buy)
    /// @return outAmt0 - expected amount of token0 to send to CFMM (sell)
    /// @return outAmt1 - expected amount of token1 to send to CFMM (sell)
    function calcInAndOutAmounts(LibStorage.Loan storage _loan, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1)
        internal returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        // can only have one non zero delta
        if(!((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0))) revert BadDelta();

        // inAmt is what GS is getting, outAmt is what GS is sending
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta0); // buy exact token0 (what you'll ask)
            inAmt1 = uint256(delta1); // buy exact token1 (what you'll ask)
            if(inAmt0 > 0) {
                outAmt0 = 0;
                outAmt1 = calcAmtOut(inAmt0, reserve1, reserve0); // calc what you'll send
                uint256 _outAmt1 = calcActualOutAmt(s.tokens[1], s.cfmm, outAmt1, s.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                if(_outAmt1 != outAmt1) {
                    outAmt1 = _outAmt1;
                    inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0); // calc what you'll ask
                }
            } else {
                outAmt0 = calcAmtOut(inAmt1, reserve0, reserve1); // calc what you'll send
                outAmt1 = 0;
                uint256 _outAmt0 = calcActualOutAmt(s.tokens[0], s.cfmm, outAmt0, s.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                if(_outAmt0 != outAmt0) {
                    outAmt0 = _outAmt0;
                    inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1); // calc what you'll ask
                }
            }
        } else {
            outAmt0 = uint256(-delta0); // sell exact token0 (what you'll send)
            outAmt1 = uint256(-delta1); // sell exact token1 (what you'll send) (here we can send then calc how much to ask)
            if(outAmt0 > 0) {
                outAmt0 = calcActualOutAmt(s.tokens[0], s.cfmm, outAmt0, s.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                inAmt0 = 0;
                inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1); // calc what you'll ask
            } else {
                outAmt1 = calcActualOutAmt(s.tokens[1], s.cfmm, outAmt1, s.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0); // calc what you'll ask
                inAmt1 = 0;
            }
        }
    }

    /// @dev Calculate actual amount received by recipient in case token has transfer fee
    /// @param token - ERC20 token whose amount we're checking
    /// @param to - recipient of token amount
    /// @param amount - amount of token we're sending to recipient (`to`)
    /// @param balance - total balance of `token` in GammaPool
    /// @param collateral - `token` collateral available in loan
    /// @return outAmt - amount of `token` actually sent to recipient (`to`)
    function calcActualOutAmt(address token, address to, uint256 amount, uint256 balance, uint256 collateral) internal
        returns(uint256) {

        uint256 balanceBefore = GammaSwapLibrary.balanceOf(token, to); // check balance before transfer
        sendToken(token, to, amount, balance, collateral); // perform transfer
        return GammaSwapLibrary.balanceOf(token, to) - balanceBefore; // check balance after transfer
    }

    /// @dev Calculate amount bought (`amtIn`) if selling exactly `amountOut`
    /// @param amountOut - amount sending to CFMM to perform swap
    /// @param reserveOut - amount in CFMM of token being sold
    /// @param reserveIn - amount in CFMM of token being bought
    /// @return amtIn - amount expected to receive in GammaPool (calculated bought amount)
    function calcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) revert ZeroReserves(); // revert if either reserve quantity in CFMM is zero

        uint256 amountOutWithFee = amountOut * tradingFee1;
        uint256 denominator = (reserveOut * tradingFee2) + amountOutWithFee;
        return amountOutWithFee * reserveIn / denominator;
    }

    /// @dev Calculate amount sold (`amtOut`) if buying exactly `amountIn`
    /// @param amountIn - amount demanding from CFMM to perform swap
    /// @param reserveOut - amount in CFMM of token being sold
    /// @param reserveIn - amount in CFMM of token being bought
    /// @return amtOut - amount expected to send to GammaPool (calculated sold amount)
    function calcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) revert ZeroReserves(); // revert if either reserve quantity in CFMM is zero

        uint256 denominator = (reserveIn - amountIn) * tradingFee1;
        return (reserveOut * amountIn * tradingFee2 / denominator) + 1;
    }
}
