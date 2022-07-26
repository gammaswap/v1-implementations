// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import "./interfaces/IPositionManager.sol";
import "./interfaces/IGammaPool.sol";
import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/ISendTokensCallback.sol";
import "./libraries/PoolAddress.sol";
import "./base/Transfers.sol";

contract PositionManager is IPositionManager, ISendTokensCallback, Transfers, ERC721 {

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;

    address public owner;

    address public immutable override factory;

    modifier isAuthorizedForToken(uint256 tokenId) {
        checkAuthorization(tokenId);
        _;
    }

    modifier isExpired(uint256 deadline) {
        checkDeadline(deadline);
        _;
    }

    function checkAuthorization(uint256 tokenId) internal view {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'FORBIDDEN');
    }

    function checkDeadline(uint256 deadline) internal view {
        require(deadline >= block.timestamp, 'EXPIRED');
    }

    constructor(address _factory, address _WETH) ERC721("PositionManager", "POS-MGR-V1") Transfers(_WETH) {
        factory = _factory;
        owner = msg.sender;
    }

    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external virtual override {
        SendTokensCallbackData memory decoded = abi.decode(data, (SendTokensCallbackData));
        require(msg.sender == PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(decoded.cfmm, decoded.protocol)), 'FORBIDDEN');

        for(uint i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) send(tokens[i], decoded.payer, payee, amounts[i]);
        }
    }

    // **** Short Gamma **** //
    function addLPLiquidity(AddLPLiquidityParams calldata params) external virtual override isExpired(params.deadline) returns(uint256 liquidity) {
        address gammaPool = PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        send(params.cfmm, msg.sender, gammaPool, params.lpTokens); // send lp tokens to pool
        return IGammaPool(gammaPool)._mint(params.to);
    }

    //TODO: missing removeLPLiquidity

    function addLiquidity(AddLiquidityParams calldata params) external virtual override isExpired(params.deadline) returns(uint256[] memory amounts, uint256 liquidity) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))
            ._addLiquidity(params.cfmm, params.amountsDesired, params.amountsMin,
            abi.encode(SendTokensCallbackData({cfmm: params.cfmm, protocol: params.protocol, payer: msg.sender})));
    }

    function removeLiquidity(RemoveLiquidityParams calldata params) external virtual override isExpired(params.deadline) returns (uint256[] memory amounts) {
        address gammaPool = PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        send(gammaPool, msg.sender, gammaPool, params.amount); // send gs tokens to pool
        amounts = IGammaPool(gammaPool)._burn(params.to);
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= params.amountsMin[i], 'amt < min');
        }
    }

    // **** LONG GAMMA **** //
    function createLoan(address cfmm, uint24 protocol, address to, uint256 deadline) external virtual override isExpired(deadline) returns(uint256 tokenId) {
        tokenId = IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(cfmm, protocol))).createLoan();
        _safeMint(to, tokenId);
    }

    function loan(address cfmm, uint24 protocol, uint256 tokenId) external virtual override view returns (uint256 id, address poolId, uint256[] memory tokensHeld,
        uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(cfmm, protocol))).loan(tokenId);
    }

    function borrowLiquidity(BorrowLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns (uint256[] memory amounts) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))._borrowLiquidity(params.tokenId, params.lpTokens);
    }

    function repayLiquidity(RepayLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns (uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))._repayLiquidity(params.tokenId, params.liquidity);
    }

    function increaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns(uint256[] memory tokensHeld) {
        address gammaPool = PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        address[] memory _tokens = IGammaPool(gammaPool).tokens();
        for (uint i = 0; i < _tokens.length; i++) {
            if (params.amounts[i] > 0 ) send(_tokens[i], msg.sender, gammaPool, params.amounts[i]);
        }
        return IGammaPool(gammaPool)._increaseCollateral(params.tokenId);
    }

    function decreaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns(uint256[] memory tokensHeld){
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))._decreaseCollateral(params.tokenId, params.amounts, params.to);
    }

    function rebalanceCollateral(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns(uint256[] memory tokensHeld) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))._rebalanceCollateral(params.tokenId, params.deltas);
    }

    function rebalanceCollateralWithLiquidity(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns(uint256[] memory tokensHeld) {
        return IGammaPool(PoolAddress.calcAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)))._rebalanceCollateralWithLiquidity(params.tokenId, params.liquidity);
    }
}