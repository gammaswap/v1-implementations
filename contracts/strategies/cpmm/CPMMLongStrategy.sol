// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../base/LiquidationStrategy.sol";
import "./CPMMBaseStrategy.sol";

contract CPMMLongStrategy is CPMMBaseStrategy, LiquidationStrategy {

    error BadDelta();

    uint16 immutable public origFee;
    uint16 immutable public tradingFee1;
    uint16 immutable public tradingFee2;

    constructor(uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint256 _baseRate, uint256 _factor, uint256 _maxApy)
        CPMMBaseStrategy(_baseRate, _factor, _maxApy) {
        origFee = _originationFee;
        tradingFee1 = _tradingFee1;
        tradingFee2 = _tradingFee2;
    }

    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    function _getCFMMPrice(address cfmm, uint256 factor) public virtual override view returns(uint256 price) {
        uint256[] memory reserves = new uint256[](2);
        (reserves[0], reserves[1],) = ICPMM(cfmm).getReserves();
        price = reserves[1] * factor / reserves[0];
    }

    function calcTokensToRepay(GammaPoolStorage.Store storage store, uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = store.lastCFMMInvariant;
        amounts[0] = liquidity * store.CFMM_RESERVES[0] / lastCFMMInvariant;
        amounts[1] = liquidity * store.CFMM_RESERVES[1] / lastCFMMInvariant;
    }

    function beforeRepay(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        sendTokens(store, _loan, store.cfmm, amounts);
    }

    function swapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        address cfmm = store.cfmm;
        ICPMM(cfmm).swap(inAmts[0],inAmts[1],address(this),new bytes(0));
    }

    function beforeSwapTokens(GammaPoolStorage.Store storage store, GammaPoolStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(_loan, store.CFMM_RESERVES[0], store.CFMM_RESERVES[1], deltas[0], deltas[1]);
    }

    function calcActualOutAmt(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal virtual returns(uint256) {
        uint256 balanceBefore = GammaSwapLibrary.balanceOf(token, to);
        sendToken(token, to, amount, balance, collateral);
        return GammaSwapLibrary.balanceOf(token, to) - balanceBefore;
    }

    function calcInAndOutAmounts(GammaPoolStorage.Loan storage _loan, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1) internal returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        if(!((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0))) {
            revert BadDelta();
        }
        GammaPoolStorage.Store storage store = GammaPoolStorage.store();
        //inAmt is what GS is getting, outAmt is what GS is sending
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta0);//buy exact token0 (what you'll ask)
            inAmt1 = uint256(delta1);//buy exact token1 (what you'll ask)
            if(inAmt0 > 0) {
                outAmt0 = 0;
                outAmt1 = calcAmtOut(inAmt0, reserve1, reserve0);//calc what you'll send
                uint256 _outAmt1 = calcActualOutAmt(IERC20(store.tokens[1]), store.cfmm, outAmt1, store.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                if(_outAmt1 != outAmt1) {
                    outAmt1 = _outAmt1;
                    inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0);//calc what you'll ask
                }
            } else {
                outAmt0 = calcAmtOut(inAmt1, reserve0, reserve1);//calc what you'll send
                outAmt1 = 0;
                uint256 _outAmt0 = calcActualOutAmt(IERC20(store.tokens[0]), store.cfmm, outAmt0, store.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                if(_outAmt0 != outAmt0) {
                    outAmt0 = _outAmt0;
                    inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);//calc what you'll ask
                }
            }
        } else {
            outAmt0 = uint256(-delta0);//sell exact token0 (what you'll send)
            outAmt1 = uint256(-delta1);//sell exact token1 (what you'll send) (here we can send then calc how much to ask)
            if(outAmt0 > 0) {
                outAmt0 = calcActualOutAmt(IERC20(store.tokens[0]), store.cfmm, outAmt0, store.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                inAmt0 = 0;
                inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);//calc what you'll ask
            } else {
                outAmt1 = calcActualOutAmt(IERC20(store.tokens[1]), store.cfmm, outAmt1, store.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0);//calc what you'll ask
                inAmt1 = 0;
            }
        }
    }

    // selling exactly amountOut
    function calcAmtIn(uint256 amountOut, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) {
            revert ZeroReserves();
        }
        uint256 amountOutWithFee = amountOut * tradingFee1;
        uint256 denominator = (reserveOut * tradingFee2) + amountOutWithFee;
        return amountOutWithFee * reserveIn / denominator;
    }

    // buying exactly amountIn
    function calcAmtOut(uint256 amountIn, uint256 reserveOut, uint256 reserveIn) internal view returns (uint256) {
        if(reserveOut == 0 || reserveIn == 0) {
            revert ZeroReserves();
        }
        uint256 denominator = (reserveIn - amountIn) * tradingFee1;
        return (reserveOut * amountIn * tradingFee2 / denominator) + 1;
    }
}
