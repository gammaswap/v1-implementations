// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import "./interfaces/IPositionManager.sol";
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/ISendTokensCallback.sol";
import "./libraries/PoolAddress.sol";
import "./base/Payments.sol";
import "./GammaPool.sol";

contract PositionManager is IPositionManager, ISendTokensCallback, Payments, ERC721 {

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;

    address public owner;

    address public immutable override factory;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'FORBIDDEN');
        _;
    }

    constructor(address _factory, address _WETH) ERC721("PositionManager", "POS-MGR-V1") Payments(_WETH) {
        factory = _factory;
        owner = msg.sender;
    }

    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external virtual override {
        SendTokensCallbackData memory decoded = abi.decode(data, (SendTokensCallbackData));
        require(msg.sender == PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(decoded.cfmm, decoded.protocol)), 'FORBIDDEN');

        for(uint i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) pay(tokens[i], decoded.payer, payee, amounts[i]);
        }
    }

    // **** ADD LIQUIDITY **** //
    function addLiquidity(AddLiquidityParams calldata params) external virtual override returns(uint[] memory amounts, uint liquidity) {
        //IGammaPool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol))).addLiquidity(params.cfmm, params.amountsDesired, params.amountsMin);
        //abi.encode(SendTokensCallbackData({cfmm: params.cfmm, protocol: params.protocol, payer: msg.sender}))
    }

    // **** REMOVE LIQUIDITY **** //
    function removeLiquidity(RemoveLiquidityParams calldata params) external virtual override returns (uint[] memory amounts) {
        /*address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        pay(gammaPool, msg.sender, gammaPool, params.amount); // send liquidity to pool
        amounts = IGammaPool(gammaPool).burn(params.to);
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= params.amountsMin[i], 'amt < min');
        }/**/
    }

    // **** LONG GAMMA **** //
    function createLoan(address cfmm, uint24 protocol, address to) external virtual override returns(uint256 tokenId) {
        //tokenId = IGammaPool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol))).createLoan();
        //_safeMint(to, tokenId);
    }

    function borrowLiquidity(BorrowLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns (uint[] memory amounts) {
        //bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        //amounts = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).borrowLiquidity(params.tokenId, params.liquidity);
    }

    function repayLiquidity(RepayLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns (uint liquidityPaid, uint256 lpTokensPaid, uint[] memory amounts) {
        //bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        //(liquidityPaid, lpTokensPaid, amounts) = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).repayLiquidity(params.tokenId, params.liquidity);
    }

    function increaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        /*address gammaPoolAddr = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        IGammaPool gammaPool = IGammaPool(gammaPoolAddr);
        address[] memory _tokens = gammaPool.tokens();
        for (uint i = 0; i < _tokens.length; i++) {
            if (params.amounts[i] > 0 ) pay(_tokens[i], msg.sender, gammaPoolAddr, params.amounts[i]);
        }
        tokensHeld = gammaPool.increaseCollateral(params.tokenId);/**/
    }

    function decreaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld){
        //bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        //tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).decreaseCollateral(params.tokenId, params.amounts, params.to);
    }

    function rebalanceCollateral(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        //bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        //tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).rebalanceCollateral(params.tokenId, params.deltas);
    }

    function rebalanceCollateralWithLiquidity(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        //bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        //tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).rebalanceCollateralWithLiquidity(params.tokenId, params.liquidity);
    }
}