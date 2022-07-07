// SPDX-License-Identifier: BSD
pragma solidity ^0.8.0;

import './libraries/GammaSwapLibrary.sol';
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/external/IUniswapV2PairMinimal.sol";
import "./base/GammaPoolERC20.sol";
import "./PositionManager.sol";

contract GammaPool is GammaPoolERC20, IGammaPool {

    uint public constant ONE = 10**18;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address public token0;
    address public token1;
    uint24 public protocol;
    address public cfmm;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public owner;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'GammaPool: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor() {
        (factory, token0, token1, protocol, cfmm) = IGammaPoolFactory(msg.sender).parameters();
        owner = msg.sender;
    }

    /*
        burn() Strategy:
            -PosManager gets totalInvariant in CFMM
            -update feeIndex with PosManager totalInvariant calc
            -PosManager checks GS liquidity value in LP Shares (Which starts by figuring out the Invariant it represents)
            -PosManager calls GSPool.burn() LP shares to withdrawer
            -update state (LPShares in Pool, BorrowedInvariant, feeIndex with new value)

        *PosManager uses modules to do all calculations. GammaPools only calc interest rates in Pool (but needs inputs from PosManager) and hold funds.
            -Therefore PosManager is GPL v3, GammaPool is BSD since GammaPool never deals with none of the open source code

        borrowLiquidity() Strategy: (might have to use some callbacks to gammapool here from posManager since posManager doesn't have permissions to move gammaPool's LP Shares. It's to avoid approvals)
            -PosManager calculates interest Rate (gets total invariant, updates BorrowedInvariant, etc.)
            -PosManager calculates what amount requested means in invariant terms, then in LP Shares
            -PosManager withdraws LP Shares and holds funds in place, increases BorrowedInvariant
            -PosManager issues NFT with description of position to borrower
            -PosManager updates state (LPShares in Pool, BorrowedInvariant, feeIndex with new value)
            *Check credit worthiness before borrowing

        repayLiquidity() Strategy: (might have to use some callbacks to gammapool here from posManager since posManager doesn't have permissions to move gammaPool's LP Shares. It's to avoid approvals)
            -PosManager calculates interest Rate
            -PosManager calculates how much payment is equal in invariant terms of loan
            -PosManager calculates P/L (Invariant difference)
            -PosManager pays back this Invariant difference

    */
    //TODO: This has to be closed to positionManager only. We have to do it through a verification of the address to save in gas
    function mint(uint totalCFMMInvariant, uint newInvariant, address to) external virtual override lock returns(uint256 liquidity) {

        /*
            Strategy:
                -check sender is PositionManager (ask factory)
                -get updated feeIndex (using totalCFMMInvariant)
                -calculate totalInvariant (totalCFMMInvariant + BorrowedInvariant * (1 + fee) [hence we need updated feeIndex])
                -calculate prorata share of invariant deposited in terms of GS LP Shares to issue
                -mint these shares (Remember to avoid the MINIMUM_LIQUIDITY bug)
                -update state (LPShares in Pool, BorrowedInvariant, feeIndex with new value)
        */

        /*this.getAndUpdateLastFeeIndex();

        uint256 _reserve0;
        uint256 _reserve1;
        (uint256 _uniReserve0, uint256 _uniReserve1) = GammaswapLibrary.getUniReserves(uniPair, token0, token1);

        uint256 _totalSupply = totalSupply;
        if(_totalSupply > 0) {
            //get reserves from uni
            (_reserve0, _reserve1) = GammaswapLibrary.getBorrowedReserves(uniPair, _uniReserve0, _uniReserve1, totalUniLiquidity, BORROWED_INVARIANT);//This is right because the liquidity has to
        }

        uint256 amountA;
        uint256 amountB;
        //TODO: Change all of this so that it is init to the invariant when there is no liquidity.
        if(amount0 > 0 && amount1 > 0) {
            (amountA, amountB, liquidity) = addLiquidity(amount0, amount1, 0, 0);
        }

        totalUniLiquidity = IERC20(uniPair).balanceOf(address(this));

        if (_totalSupply == 0) {
            liquidity = GammaswapLibrary.convertAmountsToLiquidity(amountA, amountB) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = GammaswapLibrary.min2((amountA * _totalSupply) / _reserve0, (amountB * _totalSupply) / _reserve1);//match everything that is in uniswap
        }
        require(liquidity > 0, 'DepositPool: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        //We do not update the reserves because in theory reserves should not change due to this
        //emit Mint(msg.sender, amountA, amountB);/**/
    }
}
