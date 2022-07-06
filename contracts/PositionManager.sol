// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import "./interfaces/IPositionManager.sol";
import "./interfaces/IAddLiquidityCallback.sol";
import "./interfaces/IProtocolRouter.sol";
import "./libraries/CallbackValidation.sol";
import "./base/PeripheryImmutableState.sol";
import "./base/PeripheryPayments.sol";
import "./interfaces/IGammaPool.sol";

contract PositionManager is IPositionManager, IAddLiquidityCallback, PeripheryPayments, ERC721 {

    uint256 MAX_SLIPPAGE = 10**17;//10%

    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    /// @dev IDs of pools assigned by this contract
    //mapping(address => uint80) private _poolIds;

    /// @dev Pool keys by pool ID, to save on SSTOREs for position data
    //mapping(uint80 => PoolAddress.PoolKey) private _poolIdToPoolKey;

    /// @dev The ID of the next token that will be minted. Skips 0
    uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    uint80 private _nextPoolId = 1;

    mapping(address => mapping(address => address)) public getPool;
    mapping(uint256 => address) public protocols;

    address[] public  allPools;
    address public owner;

    uint256 ONE = 10**18;//1

    /// @dev The token ID position data
    //mapping(uint256 => Position) internal _positions;

    /// @dev The token ID position data
    mapping(address => uint256) internal _tokenBalances;

    /// @dev The ID of the next token that will be minted. Skips 0
    //uint176 private _nextId = 1;
    /// @dev The ID of the next pool that is used for the first time. Skips 0
    //uint80 private _nextPoolId = 1;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'PositionManager: NOT_AUTHORIZED');
        _;
    }

    constructor(address _factory, address _WETH9) ERC721("PositionManager", "POS-MGR-V1") PeripheryImmutableState(_factory, _WETH9) {
        owner = msg.sender;
    }

    /// @inheritdoc IAddLiquidityCallback
    function addLiquidityCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        address destination,
        bytes calldata data
    ) external override {
        AddLiquidityCallbackData memory decoded = abi.decode(data, (AddLiquidityCallbackData));
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        if (amount0Owed > 0) pay(decoded.poolKey.token0, decoded.payer, destination, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, decoded.payer, destination, amount1Owed);
    }


    //A GammaPool has its own protocol router. The gammaPool no because we don't want to make the GammaPool code to work specifically with Uniswap
    //What we do is we update the GammaPool
    //Use callback to avoid having to approve every deposit pool
    //the protocolRouter is at PositionManager level because if we need to update we don't want to update every single GammaPool.
    // **** ADD LIQUIDITY ****
    function addLiquidity(AddLiquidityParams calldata params) external virtual returns (uint amountA, uint amountB, uint liquidity) {
        IProtocolRouter router = IProtocolRouter(protocols[params.protocol]);
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({token0: params.tokenA, token1: params.tokenB, protocol: params.protocol});
        address gammaPool = PoolAddress.computeAddress(factory, poolKey);
        (amountA, amountB,,) = router.addLiquidity(params, gammaPool, abi.encode(AddLiquidityCallbackData({poolKey: poolKey, payer: msg.sender})));
        liquidity = IGammaPool(gammaPool).mint(params.to);
    }

}