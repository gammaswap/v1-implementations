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
import "./GammaPool.sol";

contract PositionManager is IPositionManager, PeripheryPayments, ERC721 {

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;

    address public owner;

    uint256 ONE = 10**18;//1

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'FORBIDDEN');
        _;
    }

    constructor(address _factory, address _WETH9) ERC721("PositionManager", "POS-MGR-V1") PeripheryImmutableState(_factory, _WETH9) {
        owner = msg.sender;
    }

    // **** ADD LIQUIDITY **** //
    function addLiquidity(AddLiquidityParams calldata params) external virtual override returns(uint[] memory amounts, uint liquidity){
        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(params.protocol));//TODO: could create predetermined addresses for the protocols to not have to call them out like this
        address payee;
        (amounts, payee) = module.addLiquidity(params.cfmm, params.amountsDesired, params.amountsMin);

        IGammaPool gammaPool = IGammaPool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol)));
        address[] memory _tokens = gammaPool.tokens();

        //In Uni/Suh transfer U -> CFMM
        //In Bal/Crv transfer U -> Module
        for (uint i = 0; i < _tokens.length; i++) {
            if (amounts[i] > 0 ) pay(_tokens[i], msg.sender, payee, amounts[i]);
        }

        //In Uni/Suh mint [CFMM -> GP] single tx
        //In Bal/Crv mint [Module -> CFMM -> Module -> GP] single tx
        //                    Since CFMM has to pull from module, module must always check it has enough approval
        module.mint(params.cfmm, amounts);
        liquidity = gammaPool.mint(params.to);
    }

    // **** REMOVE LIQUIDITY **** //
    function removeLiquidity(RemoveLiquidityParams calldata params) external virtual override returns (uint[] memory amounts) {
        address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        pay(gammaPool, msg.sender, gammaPool, params.amount); // send liquidity to pool
        amounts = IGammaPool(gammaPool).burn(params.to);
        for (uint i = 0; i < amounts.length; i++) {
            require(amounts[i] >= params.amountsMin[i], 'amt < min');
        }
    }

    // **** LONG GAMMA **** //
    function createLoan(address cfmm, uint24 protocol, address to) external virtual override returns(uint256 tokenId) {
        tokenId = IGammaPool(PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol))).createLoan();
        _safeMint(to, tokenId);
    }

    function borrowLiquidity(BorrowLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns (uint[] memory amounts) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        amounts = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).borrowLiquidity(params.tokenId, params.liquidity);
    }

    function repayLiquidity(RepayLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns (uint liquidityPaid, uint256 lpTokensPaid, uint[] memory amounts) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        (liquidityPaid, lpTokensPaid, amounts) = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).repayLiquidity(params.tokenId, params.liquidity);
    }

    function increaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        address gammaPoolAddr = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(params.cfmm, params.protocol));
        IGammaPool gammaPool = IGammaPool(gammaPoolAddr);
        address[] memory _tokens = gammaPool.tokens();
        for (uint i = 0; i < _tokens.length; i++) {
            if (params.amounts[i] > 0 ) pay(_tokens[i], msg.sender, gammaPoolAddr, params.amounts[i]);
        }
        tokensHeld = gammaPool.increaseCollateral(params.tokenId);
    }

    function decreaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld){
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).decreaseCollateral(params.tokenId, params.amounts, params.to);
    }

    function rebalanceCollateral(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).rebalanceCollateral(params.tokenId, params.posDeltas, params.negDeltas);
    }

    function rebalanceCollateralWithLiquidity(RebalanceCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) returns(uint[] memory tokensHeld) {
        bytes32 poolKey = PoolAddress.getPoolKey(params.cfmm, params.protocol);
        tokensHeld = IGammaPool(PoolAddress.computeAddress(factory, poolKey)).rebalanceCollateralWithLiquidity(params.tokenId, params.liquidity);
    }
}