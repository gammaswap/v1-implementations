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
    // **** ADD LIQUIDITY ****
    function addLiquidity(AddLiquidityParams calldata params) external returns (uint[] memory amounts, uint liquidity) {
        IProtocolModule module = IProtocolModule(IGammaPoolFactory(factory).getModule(params.protocol));//We can lower this cost by having our modules created from a factory with predetermined addresses. We'll just need to input INIT_CODE_HASHES and a SALT for them
        amounts = module.addLiquidity(params.cfmm, params.amountsDesired, params.amountsMin, msg.sender);/**///Here someone could send to a gammaPool that doesn't exist. But when getting data it will fail because the gammaPool will not exist
        //since the gammaPool is tied to the CFMM address. So if the CFMM doesn't exist then it will fail there too. But nobody can create a gammaPool for a cfmm that doesn't exist so the gammaPool will fail first.
        liquidity = IGammaPool(PoolAddress.computeAddress(factory, module.getKey(params.cfmm))).mint(params.to);
    }

    function addLiquidityCallback(uint24 protocol, address[] calldata tokens, uint[] calldata amounts, address payer, address payee) external override {
        address module = IGammaPoolFactory(factory).getModule(protocol);
        require(msg.sender == module, 'PositionManager.addLiquidityCallback: FORBIDDEN');//getPool has all the pools that have been created with the contract. There's no way around that

        for (uint i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0 ) pay(tokens[i], payer, payee, amounts[i]);
        }
    }


}