// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import "./interfaces/IPositionManager.sol";
import "./interfaces/IProtocolModule.sol";
import "./base/PeripheryImmutableState.sol";
import "./base/PeripheryPayments.sol";
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./libraries/PoolAddress.sol";
import "./interfaces/IAddLiquidityCallback.sol";
import "./interfaces/IAddCollateralCallback.sol";
import "./GammaPool.sol";

contract PositionManager is IPositionManager, IAddLiquidityCallback, IAddCollateralCallback, PeripheryPayments, ERC721 {

    uint256 MAX_SLIPPAGE = 10**17;//10%

    /// @dev IDs of pools assigned by this contract
    //mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    //mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    uint80 private _nextPoolId = 1;

    address public owner;

    uint256 ONE = 10**18;//1

    /// @dev The token ID position data
    mapping(uint256 => Position) internal _positions;

    /// @dev The ID of the next token that will be minted. Skips 0
    //uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    //uint80 private _nextPoolId = 1;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'PM: NOT_AUTHORIZED');
        _;
    }

    constructor(address _factory, address _WETH9) ERC721("PositionManager", "POS-MGR-V1") PeripheryImmutableState(_factory, _WETH9) {
        owner = msg.sender;
    }

    //A GammaPool has its own protocol router. The gammaPool no because we don't want to make the GammaPool code to work specifically with Uniswap
    //What we do is we update the GammaPool
    //Use callback to avoid having to approve every deposit pool
    //the protocolRouter is at PositionManager level because if we need to update we don't want to update every single GammaPool.
    //PosMgr -> GammaPool -> Router just does calculations of what you need to send. It doesn't do anything else
    /**
        -UniSwap, SushiSwap, PancakeSwap, Balancer
        what they have in common that we need?
            -add liquidity (transfer funds and mint tokens)
            -remove liquidity (transfer tokens and retrieve funds)
            -factory, create a token at a predetermined or non predetermined address

        PosMgr
            -get GammaPool Addr
            -module.addLiq
                -callsBack PosMgr to move assets for user to cfmm
                -mint liquidity to GammaPool
                -return invariant info to PosMgr
                *Balancer and Curve works the old way, they have to transfer to us and us to balancer since their router is embedded
                 in their pool minting contract (So transfer to GammaPool then GammaPool -> Balancer -> GammaPool). Return
                 invariant info to PosMgr (Pools are not unique in their system).
                    *Curve and Balancer mint to the sender. Since PosMgr is the sender because it has control of tokens
                     then PosMgr will receive the c or b tokens. Then PosMgr has to send the tokens to GammaPool after receiving them.
                     So whatever tokens PosMGr receives it has to send to GammaPool. Other option is to have GammaPool send the tokens
                     to Balancer and Curve. But then this will mean GammaPool is not just a holder of tokens but an implementer of this
                     logic.
                    *There can be multiple pools for the same tokens
                        -This changes the factory and getCFMM function of modules.
                            -modules need to accept a pool address, tokens is not enough
                            -factory needs to create predetermined address from pool address as salt
                                -The underlying pool address + protocol is the salt (for non unique protocols) (managed, probalby don't need to manage either but we'll make publicity to only pools we know are real)
                                    -We'll retain the power to add additional protocols (modules). Then other people can create pools for those modules/protocols
                                -For unique protocols (2 Token), it's the token addresses and the protocol (non managed)
                           -Every protocol has its own rules:
                                -it's unique or not unique
                                    -If unique it can get CFMM from tokens
                                    -If not unique it needs CFMM address
                                    -GS Pool address is obtained fom tokens if Unique
                                    -GS Pool address is obtained from CFMM address if not Unique
            -call GammaPool to mint GS Tokens using invariant info
            *Will the pool ever need to know the CFMM?
    **/

    // **** ADD LIQUIDITY **** //
    function addLiquidity(AddLiquidityParams calldata params) external returns (uint[] memory amounts, uint liquidity) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        IGammaPool gammaPool = IGammaPool(PoolAddress.computeAddress(factory, poolKey));
        amounts = gammaPool.addLiquidity(params.amountsDesired, params.amountsMin, abi.encode(AddLiquidityCallbackData({ poolKey: poolKey, payer: msg.sender })));//gammaPool will do the checking afterwards that the right amounts were sent
        liquidity = gammaPool.mint(params.to);
    }

    function addLiquidityCallback(address payee, address[] calldata tokens, uint[] calldata amounts, bytes calldata data) external override {// Only in Uni. In Bal we use this to transfer to ourselves then the mint function finishes the transfer from the other side.
        AddLiquidityCallbackData memory decoded = abi.decode(data, (AddLiquidityCallbackData));
        require(msg.sender == PoolAddress.computeAddress(factory, decoded.poolKey), 'PM.addLiq: FORBIDDEN');//getPool has all the pools that have been created with the contract. There's no way around that

        for (uint i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0 ) pay(tokens[i], decoded.payer, payee, amounts[i]);
        }
    }

    // **** REMOVE LIQUIDITY **** //
    function removeLiquidity(RemoveLiquidityParams calldata params) external returns (uint[] memory amounts) {
        require(params.amount > 0, 'PM.remLiq: 0 amount');
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        pay(gammaPool, msg.sender, gammaPool, params.amount); // send liquidity to pool
        amounts = IGammaPool(gammaPool).burn(params.to);
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= params.amountsMin[i], 'PM.remLiq: amount < min');
        }
    }


    /// inheritdoc IVegaswapV1Position
    function positions(uint256 tokenId) external view returns (uint96 nonce, address operator, address poolId, address[] memory tokens,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        Position memory position = _positions[tokenId];
        //require(position.uniPair != address(0), 'PositionManager: INVALID_TOKEN_ID');
        //require(position.tokensHeld0 != 0 && position.tokensHeld1 != 0 && position.tokensHeld0 != 0, 'VegaswapV1: Invalid token ID');
        //PoolAddress.PoolKey memory poolKey = _poolIdToPoolKey[position.poolId];
        return (position.nonce, position.operator, position.poolId, position.tokens, position.tokensHeld, position.liquidity, position.rateIndex, position.blockNum);
    }

    function addCollateralCallback(address[] calldata tokens, uint[] calldata amounts, bytes calldata data) external virtual override {
        AddCollateralCallbackData memory decoded = abi.decode(data, (AddCollateralCallbackData));
        require(msg.sender == PoolAddress.computeAddress(factory, decoded.poolKey), 'PM.addColl: FORBIDDEN');//getPool has all the pools that have been created with the contract. There's no way around that

        for (uint i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0 ) pay(tokens[i], decoded.payer, msg.sender, amounts[i]);
        }
    }

    /*
     * TODO: Instead of portfolio value use invariant to measure liquidity. This will enable to also increase the position size based on liquidity
     * Also the liquidity desired should probably be measured in terms of an invariant.
     */
    //TODO: When we mint and increase positions we have to track the funds that we're holding for the pool
    /// inheritdoc IVegaswapV1Position
    //function mint(MintParams calldata params) internal returns (uint256 tokenId) {
    function borrowLiquidity(BorrowLiquidityParams calldata params) internal returns (uint[] memory amounts, uint256 tokenId) {
        //function mint(MintParams calldata params) external payable override checkDeadline(params.deadline) returns (uint256 tokenId) {
        //We transfer token0Amt and token1Amt at the same time
        //params.liquidity is the liquidity as LP shares of uni pool. In the GUI it will look like quantites of A and B. and a sum total in terms of B/A collateral
        //PositionParams memory posParams = getPositionParams(params);//your position will be in terms of A*B

        //(address _token0, address _token1) = GammaswapPosLibrary.sortTokens(params.token0, params.token1);

        require(params.liquidity > 0, 'PM.borLiq: 0 amount');

        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        IGammaPool gammaPool = IGammaPool(PoolAddress.computeAddress(factory, poolKey));
        gammaPool.addCollateral(params.collateralAmounts, abi.encode(AddCollateralCallbackData({ poolKey: poolKey, payer: msg.sender })));//gammaPool will do the checking afterwards that the right amounts were sent

        uint256 accFeeIndex;
        (amounts, accFeeIndex) = gammaPool.borrowLiquidity(params.liquidity);

        _mint(params.to, (tokenId = _nextId++));

        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: address(gammaPool),
            tokens: gammaPool.tokens(),
            tokensHeld: amounts,
            liquidity: params.liquidity,
            rateIndex: accFeeIndex,
            blockNum: block.number
        });

        Position storage position = _positions[tokenId];

        //GammaswapPosLibrary.checkCollateral(position, 750);

        /*address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        pay(gammaPool, msg.sender, gammaPool, params.amount); // send liquidity to pool

        (address _token0, address _token1) = GammaswapPosLibrary.sortTokens(token0, token1);
        address _poolId = getPool[_token0][_token1];
        require(_poolId != address(0), 'PositionManager: POOL_NOT_FOUND');

        address _uniPair = IDepositPool(_poolId).getUniPair();
        (uint256 _token0Amt, uint256 _token1Amt) = getDepositedAmounts(_token0, _token1);

        uint256 _accFeeIndex = IDepositPool(_poolId).getAndUpdateLastFeeIndex();

        //(uint256 _tokensOwed0, uint256 _tokensOwed1) = IDepositPool(_poolId).openPosition(params.liquidity);
        (uint256 _tokensOwed0, uint256 _tokensOwed1) = IDepositPool(_poolId).openPosition(liquidity);

        uint256 _liquidity = GammaswapPosLibrary.convertAmountsToLiquidity(_tokensOwed0,_tokensOwed1);//this liquidity

        //_mint(params.recipient, (tokenId = _nextId++));
        _mint(to, (tokenId = _nextId++));

        _positions[tokenId] = Position({
            nonce: 0,
            operator: address(0),
            poolId: _poolId,
            token0: _token0,
            token1: _token1,
            tokensHeld0: (_tokensOwed0 + _token0Amt),
            tokensHeld1: (_tokensOwed1 + _token1Amt),
            uniPair: _uniPair,
            //uniPairHeld: _uniPairAmt,
            liquidity: _liquidity,
            rateIndex: _accFeeIndex,
            blockNum: block.number
        });

        Position storage position = _positions[tokenId];

        GammaswapPosLibrary.checkCollateral(position, 750);

        updateTokenBalances(position);

        addPositionToOwnerList(to, tokenId);

        /**/


        /*
         * We don't have to do that whole thing up there with the token balances in saveTokenBalances.
         * We just update tokenBalances[params.token0] to whatever the current token balance is. There should never be any leftovers
         */
        /*
         * Reason why balancer is better for OTM options is because for the delta to approach 1 the price has to move much more. Which is
         * what happens with OTM options. With ATM options delta is 50 at the start. with ITM options delta is > 50 at the start.
         */
        //emit MintPosition(tokenId, _liquidity, position.tokensHeld0, position.tokensHeld1, position.uniPairHeld, _accFeeIndex);
    }


}