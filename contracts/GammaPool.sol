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
    address[] public _tokens;
    uint24 public protocol;
    address public override cfmm;

    uint256 public LP_TOKEN_BALANCE;
    uint256 public BORROWED_INVARIANT;

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address public owner;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'GammaPool: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function tokens() external view virtual override returns(address[] memory) {
        return _tokens;
    }/**/

    constructor() {
        (factory, _tokens, protocol, cfmm) = IGammaPoolFactory(msg.sender).getParameters();
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

    function updateFeeIndex() internal {
        //updates fee index and also BORROWED_INVARIANT
    }

    function getInvariantChanges() internal view returns(uint256 totalInvariant, uint256 depositedInvariant) {
        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));//Maybe this will be set permanently later on. For testing now we want to be able to update the modules as we develop
        uint256 totalInvariantInCFMM;
        (totalInvariantInCFMM, depositedInvariant) = module.getCFMMInvariantChanges(cfmm, LP_TOKEN_BALANCE);
        totalInvariant = totalInvariantInCFMM + BORROWED_INVARIANT;
    }

    function mint(address to) external virtual override lock returns(uint256 liquidity) {
        updateFeeIndex();
        (uint256 totalInvariant, uint256 depositedInvariant) = getInvariantChanges();
        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = depositedInvariant - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = (depositedInvariant * _totalSupply) / totalInvariant;
        }
        require(liquidity > 0, 'GammaPool.mint: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        //emit Mint(msg.sender, amountA, amountB);
    }
    /*
        Strategy:
            -get updated feeIndex (using totalCFMMInvariant)
            -calculate totalInvariant (totalCFMMInvariant + BorrowedInvariant * (1 + fee) [hence we need updated feeIndex])
                -can be handled through a callback too. we call positionManager (sender) to calculate totalCFMMInvariant
                    -respond must be checked that came from position manager though.
                    -positionMgr sends back its signature. When we compute its address. Just check the address
                    *If we need to update the positionManager we have to update the signature verification too unless
                    we ask the factory. We might as well just have the factory keep track of the positionManager
                    *Only calls that result in transfers need verifications.
                    *In order to avoid this whole problem. GammaPool has to use the module. But that would require
                     GammaPool having a field for the module. We want to avoid all that.
                    *Just ask positionManager, since we'll have a point to it, to do these calculatiosn for you, using
                     the module. Because what if we update the module.
                    *Since you have a pointer to factory you can always ask for the module too. Instead of having
                     the PosManager ask for the module from the factory. You can ask for the module directly to do what you need.
                    *Or you can ask the factory to do it for you, use the module. No that's putting logic where it is not needed.
                    *So module is used in GammaPool and PositionManager
                    *PosMgr moves assets to CFMM and tells CFMM to mint to GammaPool
                    then call GammaPool. Then when calling GammaPool --------
            -calculate prorata share of invariant deposited in terms of GS LP Shares to issue
            -mint these shares (Remember to avoid the MINIMUM_LIQUIDITY bug)
            -update state (LPShares in Pool, BorrowedInvariant, feeIndex with new value)
    */
}
