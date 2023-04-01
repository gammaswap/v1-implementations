// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "@gammaswap/v1-core/contracts/base/GammaPool.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "@gammaswap/v1-core/contracts/libraries/GammaSwapLibrary.sol";
import "@gammaswap/v1-core/contracts/libraries/Math.sol";

/// @title GammaPool implementation for Constant Product Market Maker
/// @author Daniel D. Alcarraz (https://github.com/0xDanr)
/// @dev This implementation is specifically for validating UniswapV2Pair and clone contracts
contract CPMMGammaPool is GammaPool {

    error NotContract();
    error BadProtocol();

    using LibStorage for LibStorage.Storage;

    /// @return tokenCount - number of tokens expected in CFMM
    uint8 constant public tokenCount = 2;

    /// @return cfmmFactory - factory contract that created CFMM
    address immutable public cfmmFactory;

    /// @return cfmmInitCodeHash - init code hash of CFMM
    bytes32 immutable public cfmmInitCodeHash;

    /// @dev Initializes the contract by setting `protocolId`, `factory`, `longStrategy`, `shortStrategy`, `liquidationStrategy`, `cfmmFactory`, and `cfmmInitCodeHash`.
    constructor(uint16 _protocolId, address _factory, address _longStrategy, address _shortStrategy, address _liquidationStrategy, address _cfmmFactory, bytes32 _cfmmInitCodeHash)
        GammaPool(_protocolId, _factory, _longStrategy, _shortStrategy, _liquidationStrategy) {
        cfmmFactory = _cfmmFactory;
        cfmmInitCodeHash = _cfmmInitCodeHash;
    }

    /// @dev See {IGammaPool-createLoan}
    function createLoan() external lock virtual override returns(uint256 tokenId) {
        tokenId = s.createLoan(tokenCount); // save gas using constant variable tokenCount
        emit LoanCreated(msg.sender, tokenId);
    }

    /// @dev See {GammaPoolERC4626.getLastCFMMPrice}.
    function _getLastCFMMPrice() internal virtual override view returns(uint256) {
        uint128[] memory _reserves = _getLatestCFMMReserves();
        return _reserves[1] * (10 ** s.decimals[0]) / _reserves[0];
    }

    /// @dev Update liquidity debt to include accrued trading fees and interest
    /// @param liquidity - liquidity debt
    /// @param rateIndex - loan's interest rate index of last update
    /// @param cfmmInvariant - total liquidity invariant of CFMM
    /// @return _liquidity - updated liquidity debt
    function updateLiquidityDebt(uint256 liquidity, uint256 rateIndex, uint256 cfmmInvariant) internal virtual view returns(uint256 _liquidity) {
        uint256 lastFeeIndex;
        (, lastFeeIndex,) = IShortStrategy(shortStrategy)
        .getLastFees(s.BORROWED_INVARIANT, s.LP_TOKEN_BALANCE, cfmmInvariant, _getLatestCFMMTotalSupply(),
            s.lastCFMMInvariant, s.lastCFMMTotalSupply, s.LAST_BLOCK_NUMBER);
        uint256 accFeeIndex = s.accFeeIndex * lastFeeIndex / 1e18;

        // accrue interest
        _liquidity = liquidity * accFeeIndex / rateIndex;
    }

    /// @dev Get loan information relevant to delta calculation
    /// @param tokenId - unique identifier of loan in GammaPool
    /// @return loanLiquidity - last loan liquidity debt (as it was after last update)
    /// @return rateIndex - loan's interest rate index of last update
    /// @return sqrtPx - square root of loan collateral ratio
    function getLoan(uint256 tokenId) internal virtual view returns(uint256 loanLiquidity, uint256 rateIndex, uint256 sqrtPx) {
        LibStorage.Loan storage _loan = s.loans[tokenId];
        loanLiquidity = _loan.liquidity;
        require(_loan.id > 0 && loanLiquidity > 0);
        uint128[] memory tokensHeld = _loan.tokensHeld;
        rateIndex = _loan.rateIndex;
        uint256 strikePx = tokensHeld[1] * (10 ** s.decimals[1]) / tokensHeld[0];
        sqrtPx = Math.sqrt(strikePx * (10 ** s.decimals[1]));
    }

    /// dev See {IGammaPool.getRebalanceDeltas2}.
    function getRebalanceDeltas2(uint128 strikePx, uint128[] memory reserves, uint128[] memory tokensHeld, uint8[] memory decimals) external virtual view returns(int256[] memory deltas) {
        uint256 fee1 = 997;
        uint256 fee2 = 1000;

        // must negate
        uint256 a = fee1 * strikePx / fee2;
        // must negate
        bool bIsNeg;
        uint256 b;
        {
            uint256 A_times_Phi = (tokensHeld[0] * fee1 / fee2);
            bIsNeg = reserves[0] < A_times_Phi;
            uint256 leftVal0 = (bIsNeg ? A_times_Phi - reserves[0] : reserves[0] - A_times_Phi);
            uint256 leftVal = leftVal0 * strikePx / (10**decimals[0]);
            uint256 rightVal = (tokensHeld[1] + reserves[1]) * fee1 / fee2;
            if(bIsNeg) {
                b = rightVal - leftVal;
                bIsNeg = rightVal > leftVal;
            } else {
                b = leftVal + rightVal;
                bIsNeg = true;
            }
        }

        uint256 det;
        {
            uint256 leftVal = tokensHeld[0] * strikePx / (10**decimals[0]);
            bool cIsNeg = leftVal < tokensHeld[1];
            uint256 c = (cIsNeg ? tokensHeld[1] - leftVal : leftVal - tokensHeld[1]) * reserves[0]; // B*A decimals
            uint256 ac4 = 4 * c * a / decimals[0];
            det = Math.sqrt(!cIsNeg ? b**2 + ac4 : b**2 - ac4); // should check here that won't get an imaginary number
        }

        // remember that a is always negative
        if(bIsNeg) { // b < 0
            // plus version
            // (b + det)/-2a = -(b + det)/2a
            // this is always negative
            // uint256 x1 = (b + det) * (10**decimals[0]) / (2*a);
            deltas[0] = -int256((b + det) * (10**decimals[0]) / (2*a));

            // minus version
            // (b - det)/-2a = (det-b)/2a
            if(det > b) {
                // x2 is positive
                // uint256 x2 = (det - b) * (10**decimals[0]) / (2*a);
                deltas[1] = int256((det - b) * (10**decimals[0]) / (2*a));
            } else {
                // x2 is negative
                // uint256 x2 = (b - det) * (10**decimals[0]) / (2*a);
                deltas[1]= -int256((b - det) * (10**decimals[0]) / (2*a));
            }
        } else { // b > 0
            // plus version
            // (-b + det)/-2a = (b - det)/2a
            if(b > det) {
                //  x1 is positive
                // uint256 x1 = (b - det) * (10**decimals[0]) / (2*a);
                deltas[0] = int256((b - det) * (10**decimals[0]) / (2*a));
            } else {
                //  x1 is negative
                // uint256 x1 = (det - b) * (10**decimals[0]) / (2*a);
                deltas[0] = -int256((det - b) * (10**decimals[0]) / (2*a));
            }

            // minus version
            // (-b - det)/-2a = (b+det)/2a
            // uint256 x2 = (b + det) * (10**decimals[0]) / (2*a);
            deltas[1] = int256((b + det) * (10**decimals[0]) / (2*a));
        }
    }

    /// @dev See {IGammaPool.getRebalanceDeltas}.
    function getRebalanceDeltas(uint256 tokenId) external virtual override view returns(int256[] memory deltas) {
        (uint256 loanLiquidity, uint256 rateIndex, uint256 sqrtPx) = getLoan(tokenId);

        uint256 liquidityFactor = 10 ** ((s.decimals[0] + s.decimals[1]) / 2);
        uint256 pxFactor = 10 ** s.decimals[1];

        uint128[] memory _reserves = _getLatestCFMMReserves();
        uint256 liquidityX = _reserves[0] * sqrtPx / pxFactor;

        uint256 cfmmInvariant = Math.sqrt(uint256(_reserves[0]) * _reserves[1]);
        loanLiquidity = updateLiquidityDebt(loanLiquidity, rateIndex, cfmmInvariant);
        bool isNeg = cfmmInvariant < liquidityX;

        uint256 collateral1 = loanLiquidity * sqrtPx / pxFactor;
        uint256 denominator = collateral1 + _reserves[1];

        uint256 numerator = loanLiquidity * (isNeg ? liquidityX - cfmmInvariant : cfmmInvariant - liquidityX) / liquidityFactor;
        uint256 delta = numerator * pxFactor / denominator;

        deltas = new int256[](2);
        deltas[0] = isNeg ? int256(delta) : -int256(delta); // if cfmmInvariant > liquidityX, we must sell so negate
        deltas[1] = 0;
    }

    /// @dev See {IGammaPool-validateCFMM}
    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata) external virtual override view returns(address[] memory _tokensOrdered) {
        if(!GammaSwapLibrary.isContract(_cfmm)) { // Not a smart contract (hence not a CFMM) or not instantiated yet
            revert NotContract();
        }

        // Order tokens to match order of tokens in CFMM
        _tokensOrdered = new address[](2);
        (_tokensOrdered[0], _tokensOrdered[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);

        // Verify CFMM was created by CFMM's factory contract
        if(_cfmm != AddressCalculator.calcAddress(cfmmFactory,keccak256(abi.encodePacked(_tokensOrdered[0], _tokensOrdered[1])),cfmmInitCodeHash)) {
            revert BadProtocol();
        }
    }

}
