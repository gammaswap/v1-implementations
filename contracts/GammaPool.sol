// SPDX-License-Identifier: BSD
pragma solidity ^0.8.0;

import './libraries/GammaSwapLibrary.sol';
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocolModule.sol";
import "./interfaces/IAddLiquidityCallback.sol";
import "./interfaces/IRemoveLiquidityCallback.sol";
import "./interfaces/IAddCollateralCallback.sol";
import "./base/GammaPoolERC20.sol";

contract GammaPool is GammaPoolERC20, IGammaPool, IRemoveLiquidityCallback {
    uint internal constant ONE = 10**18;
    uint internal constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address[] private _tokens;
    uint24 public protocol;
    address public override cfmm;

    uint256 public LP_TOKEN_BALANCE;
    uint256 public LP_TOKEN_BORROWED;
    uint256 public BORROWED_INVARIANT;

    uint256 public LAST_BLOCK_NUMBER;
    uint256 public YEAR_BLOCK_COUNT = 2252571;

    //TODO: We should test later if we can make save on gas by making public variables internal and using external getter functions
    uint256 public borrowRate;
    uint256 public accFeeIndex;
    uint256 public lastFeeIndex;
    uint256 public lastCFMMFeeIndex;
    uint256 public lastCFMMInvariant;
    uint256 public lastCFMMTotalSupply;

    address public owner;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'GP: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function tokens() external view virtual override returns(address[] memory) {
        return _tokens;
    }

    constructor() {
        factory = msg.sender;
        (_tokens, protocol, cfmm) = IGammaPoolFactory(msg.sender).getParameters();
        owner = msg.sender;
    }

    function updateBorrowRate() internal {
        borrowRate = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).calcBorrowRate(LP_TOKEN_BALANCE, LP_TOKEN_BORROWED);
    }

    function updateFeeIndex() internal {
        (lastCFMMFeeIndex, lastCFMMInvariant, lastCFMMTotalSupply) = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).getCFMMYield(cfmm, lastCFMMInvariant, lastCFMMTotalSupply);
        if(lastCFMMFeeIndex > 0) {
            uint256 blockDiff = block.number - LAST_BLOCK_NUMBER;
            uint256 adjBorrowRate = (blockDiff * borrowRate) / YEAR_BLOCK_COUNT;
            lastFeeIndex = lastCFMMFeeIndex + adjBorrowRate;
        } else {
            lastFeeIndex = ONE;
        }
        if(BORROWED_INVARIANT > 0) {
            BORROWED_INVARIANT = (BORROWED_INVARIANT * lastFeeIndex) / ONE;
            mintDevFee();
        }
        accFeeIndex = (accFeeIndex * lastFeeIndex) / ONE;
        LAST_BLOCK_NUMBER = block.number;
    }

    /*
         Formula:
             accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
             accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
             sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
     */
    function mintDevFee() internal {
        address feeTo = IGammaPoolFactory(factory).feeTo();
        uint256 devFee = IGammaPoolFactory(factory).fee();
        if(feeTo != address(0) && devFee > 0) {
            uint256 cfmmTotalInvariant = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).getCFMMTotalInvariant(cfmm);
            uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(cfmm);
            uint256 totalInvariantInCFMM = ((LP_TOKEN_BALANCE * cfmmTotalInvariant) / cfmmTotalSupply);//How much Invariant does this contract have from LP_TOKEN_BALANCE
            uint256 factor = ((lastFeeIndex - ONE) * devFee) / lastFeeIndex;//Percentage of the current growth that we will give to devs
            uint256 accGrowth = (factor * BORROWED_INVARIANT) / (BORROWED_INVARIANT + totalInvariantInCFMM);
            uint256 newDevShares = (totalSupply * accGrowth) / (ONE - accGrowth);
            _mint(feeTo, newDevShares);
        }
    }

    //********* Short Gamma Functions *********//
    function addLiquidity(uint[] calldata amountsDesired, uint[] calldata amountsMin, bytes calldata data) external virtual override returns(uint[] memory amounts){
        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));//Maybe we should just move the module here so we never have to ask for it.
        address payee;
        (amounts, payee) = module.addLiquidity(cfmm, amountsDesired, amountsMin);//for now it's ok for it to be here so we can update if we have to during testing.

        uint[] memory balanceBefore = new uint[](_tokens.length);
        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) balanceBefore[i] = GammaSwapLibrary.balanceOf(_tokens[i], payee);
        }

        //In Uni/Suh transfer U -> CFMM
        //In Bal/Crv transfer U -> Module -> GP
        IAddLiquidityCallback(msg.sender).addLiquidityCallback(payee, _tokens, amounts, data);

        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) require(balanceBefore[i] + amounts[i] == GammaSwapLibrary.balanceOf(_tokens[i], payee), 'GP: wrong amount');
        }

        //In Uni/Suh mint [CFMM -> GP] single tx
        //In Bal/Crv mint [GP -> Module -> CFMM and CFMM -> Module -> GP] single tx
        module.mint(cfmm, amounts);
    }

    function mint(address to) external virtual override lock returns(uint256 liquidity) {
        uint256 depLPBal = GammaSwapLibrary.balanceOf(cfmm, address(this)) - LP_TOKEN_BALANCE;
        require(depLPBal > 0, 'GP.mint: 0 LPT deposit');

        updateFeeIndex();

        //Maybe this will be set permanently later on. For testing now we want to be able to update the modules as we develop
        uint256 cfmmTotalInvariant = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).getCFMMTotalInvariant(cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(cfmm);

        uint256 totalInvariant = ((LP_TOKEN_BALANCE * cfmmTotalInvariant) / cfmmTotalSupply) + BORROWED_INVARIANT;
        uint256 depositedInvariant = (depLPBal * cfmmTotalInvariant) / cfmmTotalSupply;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = depositedInvariant - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = (depositedInvariant * _totalSupply) / totalInvariant;
        }
        require(liquidity > 0, 'GP.mint: 0 liquidity');
        _mint(to, liquidity);
        LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        updateBorrowRate();
        //emit Mint(msg.sender, amountA, amountB);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external virtual override lock returns (uint[] memory amounts) {
        //get the liquidity tokens
        uint256 amount = _balanceOf[address(this)];
        require(amount > 0, "GP.burn: 0 amount");

        LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));

        updateFeeIndex();
        //calculate how much in invariant units the GS Tokens you want to remove represent
        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));
        uint256 cfmmTotalInvariant = module.getCFMMTotalInvariant(cfmm);
        uint256 cfmmTotalSupply = GammaSwapLibrary.totalSupply(cfmm);

        uint256 totalLPBal = LP_TOKEN_BALANCE + (BORROWED_INVARIANT * cfmmTotalSupply) / cfmmTotalInvariant;

        uint256 withdrawLPTokens = (amount * totalLPBal) / totalSupply;
        require(withdrawLPTokens < LP_TOKEN_BALANCE, "GP.burn: exceeds liquidity");

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> U
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        amounts = module.burn(cfmm, to, withdrawLPTokens);
        _burn(address(this), amount);

        LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        updateBorrowRate();
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }

    function removeLiquidityCallback(address to, uint256 amount) external virtual override {
        require(msg.sender == IGammaPoolFactory(factory).getModule(protocol), 'GP: FORBIDDEN');
        GammaSwapLibrary.transfer(cfmm, to, amount);
    }

    //********* Long Gamma Functions *********//
    function addCollateral(uint[] calldata amounts, bytes calldata data) external virtual override {
        uint[] memory balanceBefore = new uint[](_tokens.length);
        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) balanceBefore[i] = GammaSwapLibrary.balanceOf(_tokens[i], address(this));
        }

        IAddCollateralCallback(msg.sender).addCollateralCallback(_tokens, amounts, data);

        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) require(balanceBefore[i] + amounts[i] == GammaSwapLibrary.balanceOf(_tokens[i], address(this)), 'GP: wrong amount');
        }
    }

    /*
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
    function borrowLiquidity(uint256 liquidity) external virtual override returns(uint[] memory amounts, uint accFeeIndex){
        //Could check that the position manager is the one that made the call.
        //Or I could store the tokenId here instead of in PositionManager
        //or call the module and check that the module asked for it. PM -> Mod -> GP (checks it's MOD)

        //Only owner or operator of loan should be allowed to increase the liability
        //How do you increase the liability? withdraw money from it.
        //if we store the owner in the position, then we can check msg.sender == owner
        //but what if the request comes from positionManager?
        //there also has to be a cost. Perhaps, create the tokenId here and add the collateral here too
        //How is the tokenId created here though? Callback to positionManager to create TokenId and store details in gammaPool?
        //That can be done in the same callback to addCollateral
        //but how do you prevent someone from impersonating the PositionManager and creating a tokenId that doesn't exist.
        //and storing that tokenId here?

    }
}
