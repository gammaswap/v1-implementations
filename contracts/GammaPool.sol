// SPDX-License-Identifier: BSD
pragma solidity ^0.8.0;

import './libraries/GammaSwapLibrary.sol';
import './libraries/Pool.sol';
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/IProtocolModule.sol";
import "./interfaces/ISendLiquidityCallback.sol";
import "./interfaces/ISendTokensCallback.sol";
import "./base/GammaPoolERC20.sol";

contract GammaPool is GammaPoolERC20, IGammaPool, ISendLiquidityCallback {//, ISendTokensCallback {


    using Pool for Pool.Info;
    uint internal constant ONE = 10**18;
    uint internal constant MINIMUM_LIQUIDITY = 10**3;

    address public factory;
    address[] private _tokens;
    uint24 public protocol;
    address public override cfmm;
    address public _module;

    Pool.Info public poolInfo;

    /// @dev The token ID position data
    mapping(uint256 => Pool.Loan) internal _loans;

    address public owner;

    /// @dev The ID of the next loan that will be minted. Skips 0
    uint176 private _nextId = 1;

    uint private unlocked = 1;

    modifier lock() {
        require(unlocked == 1, 'LOCK');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    /*modifier ensure(uint deadline) {//TODO: Should we use this here or in PosMgr
        require(deadline >= block.timestamp);//, 'M1: EXPIRED');
        _;
    }/**/

    constructor() {
        factory = msg.sender;
        //(_tokens, protocol, cfmm, _module) = IGammaPoolFactory(msg.sender).getParameters();
        //poolInfo.init(cfmm, _module, _tokens.length);
        owner = msg.sender;
    }

    function tokens() external view virtual override returns(address[] memory) {
        return _tokens;
    }

    //TODO: Part of delegate contract
    function updateFeeIndex() internal {
        poolInfo.updateIndex();
        if(poolInfo.BORROWED_INVARIANT > 0) {
            mintDevFee();
        }
    }

    //TODO: Part of delegate contract
    function updateLoan(Pool.Loan storage _loan) internal {
        updateFeeIndex();
        _loan.liquidity = (_loan.liquidity * poolInfo.accFeeIndex) / _loan.rateIndex;
        _loan.rateIndex = poolInfo.accFeeIndex;
    }/**/
    /*
         Formula:
             accumulatedGrowth: (1 - [borrowedInvariant/(borrowedInvariant*index)])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
             accumulatedGrowth: (1 - [1/index])*devFee*(borrowedInvariant*index/(borrowedInvariant*index + uniInvariaint))
             sharesToIssue: totalGammaTokenSupply*accGrowth/(1-accGrowth)
     */
    function mintDevFee() internal {
        (address feeTo, uint devFee) = IGammaPoolFactory(factory).feeInfo();
        if(feeTo != address(0) && devFee > 0) {
            //_mint(feeTo, IProtocolModule(_module).calcNewDevShares(cfmm, devFee, poolInfo.lastFeeIndex, totalSupply, poolInfo.LP_TOKEN_BALANCE, poolInfo.BORROWED_INVARIANT));
        }
    }

    //TODO: Can be delegated (Part of Abstract Contract)
    //********* Short Gamma Functions *********//
    function mint(address to) external virtual override lock returns(uint256 liquidity) {
        uint256 depLPBal = GammaSwapLibrary.balanceOf(cfmm, address(this)) - poolInfo.LP_TOKEN_BALANCE;
        require(depLPBal > 0, '0 dep');

        updateFeeIndex();

        (uint256 totalInvariant, uint256 depositedInvariant) = poolInfo.calcDepositedInvariant(depLPBal);

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = depositedInvariant - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = (depositedInvariant * _totalSupply) / totalInvariant;
        }
        _mint(to, liquidity);
        poolInfo.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        //emit Mint(msg.sender, amountA, amountB);
    }

    //TODO: Can be delegated (Part of Abstract Contract)
    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) external virtual override lock returns (uint[] memory amounts) {
        //get the liquidity tokens
        uint256 amount = _balanceOf[address(this)];
        require(amount > 0, '0 dep');

        updateFeeIndex();

        uint256 totalLPBal = poolInfo.calcTotalLPBalance();

        uint256 withdrawLPTokens = (amount * totalLPBal) / totalSupply;
        require(withdrawLPTokens < poolInfo.LP_TOKEN_BALANCE, '> liq');

        //Uni/Sus: U -> GP -> CFMM -> U
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> U
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        //amounts = IProtocolModule(_module).burn(cfmm, to, withdrawLPTokens);
        _burn(address(this), amount);

        poolInfo.LP_TOKEN_BALANCE = GammaSwapLibrary.balanceOf(cfmm, address(this));
        //emit Burn(msg.sender, _amount0, _amount1, uniLiquidity, to);
    }

    //********* Long Gamma Functions *********//
    function checkMargin(Pool.Loan storage _loan, uint24 limit) internal view {
        require(_loan.heldLiquidity * limit / 1000 >= _loan.liquidity, 'margin');
    }

    //TODO: Can be delegated
    function loans(uint256 tokenId) external virtual override view returns (uint96 nonce, address operator, uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        Pool.Loan memory loan = _loans[tokenId];
        return (loan.nonce, loan.operator, loan.id, loan.poolId, loan.tokensHeld, loan.liquidity, loan.rateIndex, loan.blockNum);
    }

    //TODO: Shouldn't exist
    function updateCollateral(Pool.Loan storage _loan) internal {
        for (uint i = 0; i < _tokens.length; i++) {
            uint256 tokenBal = GammaSwapLibrary.balanceOf(_tokens[i], address(this)) - poolInfo.TOKEN_BALANCE[i];
            if(tokenBal > 0) {
                _loan.tokensHeld[i] = _loan.tokensHeld[i] + tokenBal;
                poolInfo.TOKEN_BALANCE[i] = poolInfo.TOKEN_BALANCE[i] + tokenBal;
            }
        }
        _loan.heldLiquidity = 0;//IProtocolModule(_module).calcInvariant(cfmm, _loan.tokensHeld);
    }

    //TODO: Can be delegated
    function increaseCollateral(uint256 tokenId) external virtual override lock returns(uint[] memory) {
        Pool.Loan storage _loan = getLoan(tokenId);
        updateCollateral(_loan);
        return _loan.tokensHeld;
    }

    //TODO: Can be delegated
    function decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override lock returns(uint[] memory){
        Pool.Loan storage _loan = getLoan(tokenId);

        for(uint i = 0; i < _tokens.length; i++) {
            require(_loan.tokensHeld[i] > amounts[i], '> amt');
            GammaSwapLibrary.transfer(_tokens[i], to, amounts[i]);
            _loan.tokensHeld[i] = _loan.tokensHeld[i] - amounts[i];
            poolInfo.TOKEN_BALANCE[i] = poolInfo.TOKEN_BALANCE[i] - amounts[i];
        }

        updateLoan(_loan);
        _loan.heldLiquidity = 0;//IProtocolModule(_module).calcInvariant(cfmm, _loan.tokensHeld);

        checkMargin(_loan, 800);
        return _loan.tokensHeld;
    }

    //TODO: Shouldn't Exist
    function sendLiquidityCallback(address to, uint256 amount) external virtual override {
        require(msg.sender == _module, 'FORBIDDEN');
        GammaSwapLibrary.transfer(cfmm, to, amount);
    }

    //TODO: Shouldn't Exist
    /*function sendTokensCallback(uint[] calldata amounts, address to) external virtual override {
        require(msg.sender == _module, 'FORBIDDEN');
        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0) GammaSwapLibrary.transfer(_tokens[i], to, amounts[i]);
        }
    }/**/

    function createLoan() external virtual override lock returns(uint tokenId) {
        uint256 id = _nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        _loans[tokenId] = Pool.Loan({
            nonce: 0,
            id: id,
            operator: address(0),
            poolId: address(this),
            tokensHeld: new uint[](_tokens.length),
            heldLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: poolInfo.accFeeIndex,
            blockNum: block.number
        });
    }

    //TODO: Can be delegated
    function borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override lock returns(uint[] memory amounts){
        require(lpTokens < poolInfo.LP_TOKEN_BALANCE, '> liq');

        updateFeeIndex();

        IProtocolModule module = IProtocolModule(_module);

        //Uni/Sus: U -> GP -> CFMM -> GP
        //                    just call module and ask module to use callback to transfer to CFMM then module calls burn
        //Bal/Crv: U -> GP -> Module -> CFMM -> Module -> GP
        //                    just call module and ask module to use callback to transfer to Module then to CFMM
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        //amounts = module.burn(cfmm, address(this), lpTokens);

        Pool.Loan storage _loan = getLoan(tokenId);
        updateCollateral(_loan);

        //poolInfo.openLoan(_loan, module.calcInvariant(cfmm, amounts), lpTokens);
        require(poolInfo.LP_TOKEN_BALANCE == GammaSwapLibrary.balanceOf(cfmm, address(this)), 'LP < Bal');
        //***************END DELEGATE************//

        checkMargin(_loan, 800);
    }

    //TODO: Can be delegated
    function repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        Pool.Loan storage _loan = getLoan(tokenId);

        updateLoan(_loan);

        //(_loan.tokensHeld, amounts, lpTokensPaid, liquidityPaid) = IProtocolModule(_module).repayLiquidity(cfmm, liquidity, _loan.tokensHeld);//calculate amounts and pay all in one call

        poolInfo.payLoan(_loan, liquidityPaid, lpTokensPaid);

        //Do I have the amounts in the tokensHeld?
        //so to swap you send the amount you want to swap to CFMM
        //Uni/Sushi/UniV3: GP -> CFMM -> GP
        //Bal/Crv: GP -> Module -> CFMM -> Module -> GP
        //UniV3
    }

    //TODO: Can be delegated (Abstract)
    function rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override lock returns(uint256[] memory tokensHeld) {
        Pool.Loan storage _loan = getLoan(tokenId);

        updateLoan(_loan);

        //tokensHeld = IProtocolModule(_module).rebalancePosition(cfmm, deltas, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }

    function getLoan(uint256 tokenId) internal returns(Pool.Loan storage _loan) {
        _loan = _loans[tokenId];
        require(_loan.id > 0, '0 id');
        require(tokenId == uint256(keccak256(abi.encode(msg.sender, address(this), _loan.id))), 'FORBIDDEN');
    }

    //TODO: Can be delegated (Abstract)
    function rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external virtual override lock returns(uint256[] memory tokensHeld) {
        Pool.Loan storage _loan = getLoan(tokenId);

        updateLoan(_loan);

        //tokensHeld = IProtocolModule(_module).rebalancePosition(cfmm, liquidity, _loan.tokensHeld);
        checkMargin(_loan, 850);
        _loan.tokensHeld = tokensHeld;
    }
}
