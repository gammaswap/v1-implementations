// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "@gammaswap/v1-core/contracts/strategies/base/BaseLongStrategy.sol";
import "./CPMMBaseStrategy.sol";
import "../../../interfaces/external/IFeeSource.sol";

/// @title Base Long Strategy abstract contract for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @notice Common functions used by all concrete strategy implementations for CPMM that need access to loans
/// @dev This implementation was specifically designed to work with UniswapV2.
abstract contract CPMMBaseLongStrategy is BaseLongStrategy, CPMMBaseStrategy {

    error BadDelta();
    error ZeroReserves();
    error InvalidTradingFee();
    error InsufficientTokenRepayment();

    /// @return feeSource - source of tradingFee for tradingFee1
    address immutable public feeSource;

    /// @return tradingFee1 - numerator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2)
    uint24 immutable public tradingFee1;

    /// @return tradingFee2 - denominator in tradingFee calculation (e.g amount * tradingFee1 / tradingFee2)
    uint24 immutable public tradingFee2 ;

    /// @return Returns the minimum liquidity payment amount.
    uint256 constant public MIN_PAY = 1e3;

    /// @dev Initializes the contract by setting `MAX_TOTAL_APY`, `BLOCKS_PER_YEAR`, `tradingFee1`, `tradingFee2`,
    /// @dev `feeSource`, `baseRate`, `optimalUtilRate`, `slope1`, and `slope2`
    constructor(uint256 maxTotalApy_, uint256 blocksPerYear_, uint24 tradingFee1_, uint24 tradingFee2_, address _feeSource,
        uint64 baseRate_, uint64 optimalUtilRate_, uint64 slope1_, uint64 slope2_) CPMMBaseStrategy(maxTotalApy_,
        blocksPerYear_, baseRate_, optimalUtilRate_, slope1_, slope2_) {
        if(tradingFee1_ > tradingFee2_) revert InvalidTradingFee();
        tradingFee1 = tradingFee1_;
        tradingFee2 = tradingFee2_;
        feeSource = _feeSource;
    }

    /// @return Returns the minimum liquidity amount to pay.
    function minPay() internal virtual override view returns(uint256) {
        return MIN_PAY;
    }

    /// @dev See {BaseLongStrategy-calcTokensToRepay}.
    function calcTokensToRepay(uint128[] memory reserves, uint256 liquidity, uint128[] memory maxAmounts) internal virtual override view
        returns(uint256[] memory amounts) {

        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = calcInvariant(address(0), reserves);

        uint256 lastCFMMTotalSupply = s.lastCFMMTotalSupply;
        uint256 expectedLPTokens = liquidity * lastCFMMTotalSupply / lastCFMMInvariant;

        amounts[0] = expectedLPTokens * reserves[0] / lastCFMMTotalSupply + 1;
        amounts[1] = expectedLPTokens * reserves[1] / lastCFMMTotalSupply + 1;

        if(maxAmounts.length == 2) {
            if(amounts[0] > maxAmounts[0]) {
                unchecked {
                    if(amounts[0] - maxAmounts[0] > 1000) revert InsufficientTokenRepayment();
                }
            }
            if(amounts[1] > maxAmounts[1]) {
                unchecked {
                    if(amounts[1] - maxAmounts[1] > 1000) revert InsufficientTokenRepayment();
                }
            }
            amounts[0] = GSMath.min(amounts[0], maxAmounts[0]);
            amounts[1] = GSMath.min(amounts[1], maxAmounts[1]);
        }
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
        if(inAmts[0] == 0 && inAmts[1] == 0) return;

        ICPMM(s.cfmm).swap(inAmts[0],inAmts[1],address(this),new bytes(0)); // out amounts already sent in beforeSwapTokens
    }

    /// @dev See {BaseLongStrategy-beforeSwapTokens}.
    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] memory deltas, uint128[] memory reserves)
        internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {

        outAmts = new uint256[](2);
        inAmts = new uint256[](2);

        if(deltas[0] == 0 && deltas[1] == 0) {
            return (outAmts, inAmts);
        }

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

        uint256 amountOutWithFee = amountOut * getTradingFee1();
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

        uint256 denominator = (reserveIn - amountIn) * getTradingFee1();
        return (reserveOut * amountIn * tradingFee2 / denominator) + 1;
    }

    function getTradingFee1() internal view returns(uint24) {
        return feeSource == address(0) ? tradingFee1 : tradingFee2 - IFeeSource(feeSource).gsFee();
    }
}
