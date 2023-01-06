pragma solidity ^0.8.0;

import "../base/BaseLongStrategy.sol";
import "./CPMMBaseStrategy.sol";

abstract contract CPMMBaseLongStrategy is BaseLongStrategy, CPMMBaseStrategy {

    error BadDelta();
    error ZeroReserves();

    uint16 immutable public origFee;
    uint16 immutable public tradingFee1;
    uint16 immutable public tradingFee2;

    constructor(uint256 _blocksPerYear, uint16 _originationFee, uint16 _tradingFee1, uint16 _tradingFee2, uint64 _baseRate, uint80 _factor, uint80 _maxApy)
        CPMMBaseStrategy(_blocksPerYear, _baseRate, _factor, _maxApy) {
        origFee = _originationFee;
        tradingFee1 = _tradingFee1;
        tradingFee2 = _tradingFee2;
    }

    function originationFee() internal virtual override view returns(uint16) {
        return origFee;
    }

    function calcTokensToRepay(uint256 liquidity) internal virtual override view returns(uint256[] memory amounts) {
        amounts = new uint256[](2);
        uint256 lastCFMMInvariant = s.lastCFMMInvariant;
        amounts[0] = liquidity * s.CFMM_RESERVES[0] / lastCFMMInvariant;
        amounts[1] = liquidity * s.CFMM_RESERVES[1] / lastCFMMInvariant;
    }

    function beforeRepay(LibStorage.Loan storage _loan, uint256[] memory amounts) internal virtual override {
        sendTokens(_loan, s.cfmm, amounts);
    }

    function swapTokens(LibStorage.Loan storage _loan, uint256[] memory outAmts, uint256[] memory inAmts) internal virtual override {
        ICPMM(s.cfmm).swap(inAmts[0],inAmts[1],address(this),new bytes(0));
    }

    function beforeSwapTokens(LibStorage.Loan storage _loan, int256[] calldata deltas) internal virtual override returns(uint256[] memory outAmts, uint256[] memory inAmts) {
        outAmts = new uint256[](2);
        inAmts = new uint256[](2);
        (inAmts[0], inAmts[1], outAmts[0], outAmts[1]) = calcInAndOutAmounts(_loan, s.CFMM_RESERVES[0], s.CFMM_RESERVES[1], deltas[0], deltas[1]);
    }

    function calcInAndOutAmounts(LibStorage.Loan storage _loan, uint256 reserve0, uint256 reserve1, int256 delta0, int256 delta1)
        internal returns(uint256 inAmt0, uint256 inAmt1, uint256 outAmt0, uint256 outAmt1) {
        if(!((delta0 != 0 && delta1 == 0) || (delta0 == 0 && delta1 != 0))) {
            revert BadDelta();
        }
        //inAmt is what GS is getting, outAmt is what GS is sending
        if(delta0 > 0 || delta1 > 0) {
            inAmt0 = uint256(delta0);//buy exact token0 (what you'll ask)
            inAmt1 = uint256(delta1);//buy exact token1 (what you'll ask)
            if(inAmt0 > 0) {
                outAmt0 = 0;
                outAmt1 = calcAmtOut(inAmt0, reserve1, reserve0);//calc what you'll send
                uint256 _outAmt1 = calcActualOutAmt(IERC20(s.tokens[1]), s.cfmm, outAmt1, s.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                if(_outAmt1 != outAmt1) {
                    outAmt1 = _outAmt1;
                    inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0);//calc what you'll ask
                }
            } else {
                outAmt0 = calcAmtOut(inAmt1, reserve0, reserve1);//calc what you'll send
                outAmt1 = 0;
                uint256 _outAmt0 = calcActualOutAmt(IERC20(s.tokens[0]), s.cfmm, outAmt0, s.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                if(_outAmt0 != outAmt0) {
                    outAmt0 = _outAmt0;
                    inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);//calc what you'll ask
                }
            }
        } else {
            outAmt0 = uint256(-delta0);//sell exact token0 (what you'll send)
            outAmt1 = uint256(-delta1);//sell exact token1 (what you'll send) (here we can send then calc how much to ask)
            if(outAmt0 > 0) {
                outAmt0 = calcActualOutAmt(IERC20(s.tokens[0]), s.cfmm, outAmt0, s.TOKEN_BALANCE[0], _loan.tokensHeld[0]);
                inAmt0 = 0;
                inAmt1 = calcAmtIn(outAmt0, reserve0, reserve1);//calc what you'll ask
            } else {
                outAmt1 = calcActualOutAmt(IERC20(s.tokens[1]), s.cfmm, outAmt1, s.TOKEN_BALANCE[1], _loan.tokensHeld[1]);
                inAmt0 = calcAmtIn(outAmt1, reserve1, reserve0);//calc what you'll ask
                inAmt1 = 0;
            }
        }
    }

    function calcActualOutAmt(IERC20 token, address to, uint256 amount, uint256 balance, uint256 collateral) internal returns(uint256) {
        uint256 balanceBefore = GammaSwapLibrary.balanceOf(token, to);
        sendToken(token, to, amount, balance, collateral);
        return GammaSwapLibrary.balanceOf(token, to) - balanceBefore;
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
