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
    function addLiquidity(AddLiquidityParams calldata params) external virtual returns (uint[] memory amounts, uint liquidity) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        IGammaPool gammaPool = IGammaPool(PoolAddress.computeAddress(factory, poolKey));
        amounts = gammaPool.addLiquidity(params.amountsDesired, params.amountsMin, abi.encode(AddLiquidityCallbackData({ poolKey: poolKey, payer: msg.sender })));//gammaPool will do the checking afterwards that the right amounts were sent
        liquidity = gammaPool.mint(params.to);
    }

    function addLiquidityCallback(address payee, address[] calldata tokens, uint[] calldata amounts, bytes calldata data) external virtual override {// Only in Uni. In Bal we use this to transfer to ourselves then the mint function finishes the transfer from the other side.
        AddLiquidityCallbackData memory decoded = abi.decode(data, (AddLiquidityCallbackData));
        require(msg.sender == PoolAddress.computeAddress(factory, decoded.poolKey), 'PM.addLiq: FORBIDDEN');//getPool has all the pools that have been created with the contract. There's no way around that

        for (uint i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0 ) pay(tokens[i], decoded.payer, payee, amounts[i]);
        }
    }

    // **** REMOVE LIQUIDITY **** //
    function removeLiquidity(RemoveLiquidityParams calldata params) external virtual returns (uint[] memory amounts) {
        require(params.amount > 0, 'PM.remLiq: 0 amount');
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        pay(gammaPool, msg.sender, gammaPool, params.amount); // send liquidity to pool
        amounts = IGammaPool(gammaPool).burn(params.to);
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= params.amountsMin[i], 'PM.remLiq: amount < min');
        }
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
    function borrowLiquidity(BorrowLiquidityParams calldata params) external virtual returns (uint[] memory amounts, uint256 tokenId) {
        require(params.liquidity > 0, 'PM.borLiq: 0 amount');
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        (amounts, tokenId) = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).borrowLiquidity(params.liquidity, params.collateralAmounts, abi.encode(AddCollateralCallbackData({ poolKey: poolKey, payer: msg.sender })));
        _safeMint(params.to, tokenId);
    }

    function borrowMoreLiquidity(uint256 tokenId, BorrowLiquidityParams calldata params) external virtual returns (uint[] memory amounts) {
        require(params.liquidity > 0, 'PM.borLiq: 0 amount');
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        amounts = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).borrowMoreLiquidity(tokenId, params.liquidity, params.collateralAmounts, abi.encode(AddCollateralCallbackData({ poolKey: poolKey, payer: msg.sender })));
    }

    /*
         * TODO: Instead of portfolio value use invariant to measure liquidity. This will enable to also increase the position size based on liquidity
         * Also the liquidity desired should probably be measured in terms of an invariant.

        repayLiquidity() Strategy: (might have to use some callbacks to gammapool here from posManager since posManager doesn't have permissions to move gammaPool's LP Shares. It's to avoid approvals)
            -PosManager calculates interest Rate
            -PosManager calculates how much payment is equal in invariant terms of loan
            -PosManager calculates P/L (Invariant difference)
            -PosManager pays back this Invariant difference

         */
    //TODO: When we mint and increase positions we have to track the funds that we're holding for the pool
    /// inheritdoc IVegaswapV1Position
    //function mint(MintParams calldata params) internal returns (uint256 tokenId) {
    function repayLiquidity(RepayLiquidityParams calldata params) external returns (uint[] memory amounts) {
        require(params.liquidity > 0, 'PM.repLiq: 0 amount');
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        amounts = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).repayLiquidity(params.tokenId, params.liquidity, params.amounts, abi.encode(AddCollateralCallbackData({ poolKey: poolKey, payer: msg.sender })));
    }

    function increaseCollateral(ChangeCollateralParams calldata params) external virtual {
        require(params.tokenId > 0, 'PM.incColl: 0 tokenId');
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        IGammaPool(PoolAddress.computeAddress(factory, poolKey)).increaseCollateral(params.tokenId, params.amounts, abi.encode(AddCollateralCallbackData({ poolKey: poolKey, payer: msg.sender })));
    }

    function decreaseCollateral(ChangeCollateralParams calldata params) external virtual {
        require(params.tokenId > 0, 'PM.decColl: 0 tokenId');
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        IGammaPool(PoolAddress.computeAddress(factory, poolKey)).decreaseCollateral(params.tokenId, params.amounts, params.to);
    }
}