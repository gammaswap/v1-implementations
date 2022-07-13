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

    /// @dev The token ID position data
    mapping(uint256 => Loan) internal _loans;

    //TODO: We should test later if we can make save on gas by making public variables internal and using external getter functions
    uint256 public borrowRate;
    uint256 public accFeeIndex;
    uint256 public lastFeeIndex;
    uint256 public lastCFMMFeeIndex;
    uint256 public lastCFMMInvariant;
    uint256 public lastCFMMTotalSupply;

    address public owner;

    /// @dev The ID of the next loan that will be minted. Skips 0
    uint176 private _nextId = 1;

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
        //In Bal/Crv transfer U -> Module
        IAddLiquidityCallback(msg.sender).addLiquidityCallback(payee, _tokens, amounts, data);

        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) require(balanceBefore[i] + amounts[i] == GammaSwapLibrary.balanceOf(_tokens[i], payee), 'GP: wrong amount');
        }

        //In Uni/Suh mint [CFMM -> GP] single tx
        //In Bal/Crv mint [Module -> CFMM -> Module -> GP] single tx
        //                    Since CFMM has to pull from module, module must always check it has enough approval
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
        //                    Since CFMM has to pull from module, module must always check it has enough approval
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
    function loans(uint256 tokenId) external view returns (uint96 nonce, address operator, uint256 id, address poolId, address[] memory tokens,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        Loan memory loan = _loans[tokenId];
        return (loan.nonce, loan.operator, loan.id, loan.poolId, loan.tokens, loan.tokensHeld, loan.liquidity, loan.rateIndex, loan.blockNum);
    }

    function addCollateral(uint[] calldata amounts, bytes calldata data) internal {
        uint[] memory balanceBefore = new uint[](_tokens.length);
        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) balanceBefore[i] = GammaSwapLibrary.balanceOf(_tokens[i], address(this));
        }

        IAddCollateralCallback(msg.sender).addCollateralCallback(_tokens, amounts, data);

        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) require(balanceBefore[i] + amounts[i] == GammaSwapLibrary.balanceOf(_tokens[i], address(this)), 'GP: wrong amount');
        }
    }

    function increaseCollateral(uint256 tokenId, uint256[] calldata amounts, bytes calldata data) external virtual override {
        Loan storage _loan = _loans[tokenId];
        require(_loan.id > 0, "GP: NOT_EXISTS");

        addCollateral(amounts, data);

        for(uint i = 0; i < _loan.tokensHeld.length; i++) {
            _loan.tokensHeld[i] = _loan.tokensHeld[i] + amounts[i];
        }
    }

    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override {
        Loan storage _loan = _loans[tokenId];
        require(_loan.id > 0, "GP: NOT_EXISTS");
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))));

        for(uint i = 0; i < _tokens.length; i++) {
            require(_loan.tokensHeld[i] > amounts[i]);
            GammaSwapLibrary.transfer(_tokens[i], to, amounts[i]);
            _loan.tokensHeld[i] = _loan.tokensHeld[i] - amounts[i];
        }

        updateFeeIndex();

        _loan.liquidity = (_loan.liquidity * accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = accFeeIndex;
        require(IProtocolModule(IGammaPoolFactory(factory).getModule(protocol)).checkCollateral(cfmm, _loan.tokensHeld, _loan.liquidity));
    }

    /*
        repayLiquidity() Strategy: (might have to use some callbacks to gammapool here from posManager since posManager doesn't have permissions to move gammaPool's LP Shares. It's to avoid approvals)
            -PosManager calculates interest Rate
            -PosManager calculates how much payment is equal in invariant terms of loan
            -PosManager calculates P/L (Invariant difference)
            -PosManager pays back this Invariant difference
    */
    function borrowLiquidity(uint256 lpTokens, uint256[] calldata collateralAmounts, bytes calldata data) external virtual override returns(uint[] memory amounts, uint tokenId){
        require(lpTokens < LP_TOKEN_BALANCE, "GP.borLiq: > avail liquidity");

        updateFeeIndex();

        addCollateral(collateralAmounts, data);

        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));

        //Uni/Sus: U -> GP -> CFMM -> GP
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> GP
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        amounts = module.burn(cfmm, address(this), lpTokens);
        uint256 invariantBorrowed = module.calcInvariant(cfmm, amounts);

        BORROWED_INVARIANT = BORROWED_INVARIANT + invariantBorrowed;
        LP_TOKEN_BORROWED = LP_TOKEN_BORROWED + lpTokens;
        LP_TOKEN_BALANCE = LP_TOKEN_BALANCE - lpTokens;
        require(LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(cfmm, address(this)));
        //TODO: Should probably also put a check for the amounts we withdrew

        updateBorrowRate();
        uint[] memory tokensHeld = new uint[](_tokens.length);
        for(uint i = 0; i < _tokens.length; i++) {
            tokensHeld[i] = amounts[i] + collateralAmounts[i];
        }

        require(module.checkCollateral(cfmm, tokensHeld, invariantBorrowed));//TODO: Finish this implementation

        uint256 id = _nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        _loans[tokenId] = Loan({
            nonce: 0,
            id: id,
            operator: address(0),
            poolId: address(this),
            tokens: _tokens,
            tokensHeld: tokensHeld,
            liquidity: invariantBorrowed,
            rateIndex: accFeeIndex,
            blockNum: block.number
        });
    }

    function borrowMoreLiquidity(uint256 tokenId, uint256 lpTokens, uint256[] calldata collateralAmounts, bytes calldata data) external virtual override returns(uint[] memory amounts){
        require(lpTokens < LP_TOKEN_BALANCE, "GP.borLiq: > avail liquidity");
        Loan storage _loan = _loans[tokenId];
        require(_loan.id > 0, "GP: NOT_EXISTS");
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))));

        updateFeeIndex();

        addCollateral(collateralAmounts, data);

        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));

        //Uni/Sus: U -> GP -> CFMM -> GP
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> GP
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        amounts = module.burn(cfmm, address(this), lpTokens);
        uint256 invariantBorrowed = module.calcInvariant(cfmm, amounts);
        _loan.liquidity = ((_loan.liquidity * accFeeIndex) / _loan.rateIndex) + invariantBorrowed;
        _loan.rateIndex = accFeeIndex;

        BORROWED_INVARIANT = BORROWED_INVARIANT + invariantBorrowed;
        LP_TOKEN_BORROWED = LP_TOKEN_BORROWED + lpTokens;
        LP_TOKEN_BALANCE = LP_TOKEN_BALANCE - lpTokens;
        require(LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(cfmm, address(this)));

        updateBorrowRate();
        for(uint i = 0; i < _tokens.length; i++) {
            _loan.tokensHeld[i] = _loan.tokensHeld[i] + amounts[i] + collateralAmounts[i];
        }

        require(module.checkCollateral(cfmm, _loan.tokensHeld, _loan.liquidity));//TODO: Finish this implementation
    }

    function repayLiquidity(uint256 tokenId, uint256 liquidity, uint256[] calldata collateralAmounts, bytes calldata data) external virtual override returns(uint256[] memory amounts) {
        //require(lpTokens < LP_TOKEN_BALANCE, "GP.borLiq: > avail liquidity");
        Loan storage _loan = _loans[tokenId];
        require(_loan.id > 0, "GP: NOT_EXISTS");
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))));

        updateFeeIndex();
        _loan.liquidity = (_loan.liquidity * accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = accFeeIndex;

        if(liquidity > _loan.liquidity) {
            liquidity = _loan.liquidity;
        }

        addCollateral(collateralAmounts, data);

        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(protocol));
        amounts = module.convertLiquidityToAmounts(cfmm, liquidity);//amounts I will pay

        /*
            User decides whether he wants to close proportionally or not. If closing proportionally then need to swap.
            If not closing proportionally then only swap if need to.

            If closing proportionally, calculate percentage that is closing and take that same percentage from collateral.
            Then work with only that percentage of collateral to calculate the amounts needed to swap

            If not closing proportionally, just swap as you need

            call module.rebalancePosition(amounts,tokensHeld,percentage)//percentage = ONE means use the whole thing. < 1 means proportional.
                //this function does a callback to GP to send the tokens necessary to CFMM (in Uni/Sushi) or Module (Bal/Crv)
                //then this function does the swap and gives back the tokens to GP (in Bal/Crv) (no need for Uni/Sushi since the swap does it automatically
                //This function checks that it is called by GP
            then call module.mint() just add the amounts to get the LP Tokens you want and pay the liquidity
            then update LP_TOKEN_BORROWED, LP_TOKEN_BALANCE, BORROWED_INVARIANT, borrowRate, and accFeeIndex
            //We'll probably move a lot of code to libraries and call them using "using for" like UniV3 does to save memory
        */

        //Do I have the amounts in the tokensHeld?
        //so to swap you send the amount you want to swap to CFMM
        //Uni/Sushi/UniV3: GP -> CFMM -> GP
        //Bal/Crv: GP -> Module -> CFMM -> Module -> GP
        //UniV3

    }
}
