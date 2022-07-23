// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/IGammaPoolFactory.sol";

library GammaPoolStorage {
    bytes32 constant STRUCT_POSITION = keccak256("com.gammaswap.gammapool.store");

    struct Loan {
        uint256 id;
        address poolId;
        uint256[] tokensHeld;
        uint256 heldLiquidity;
        uint256 liquidity;
        uint256 lpTokens;
        uint256 rateIndex;
        uint256 blockNum;
    }

    struct GammaPoolStore {
        address factory;
        address[] tokens;
        uint24 protocol;
        address cfmm;
        address module;

        uint256[] TOKEN_BALANCE;
        uint256 LP_TOKEN_BALANCE;
        uint256 LP_TOKEN_BORROWED;
        uint256 LP_BORROWED;//(BORROWED_INVARIANT as LP Tokens)
        uint256 LP_TOKEN_TOTAL;//LP_TOKEN_BALANCE + LP_BORROWED
        uint256 BORROWED_INVARIANT;
        uint256 LP_INVARIANT;//Invariant from LP Tokens
        uint256 TOTAL_INVARIANT;//BORROWED_INVARIANT + LP_INVARIANT
        uint256[] CFMM_RESERVES;
        uint256 borrowRate;
        uint256 accFeeIndex;
        uint256 lastFeeIndex;
        uint256 lastCFMMFeeIndex;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
        uint256 lastPx;
        uint256 LAST_BLOCK_NUMBER;

        /// @dev The token ID position data
        mapping(uint256 => Loan) loans;

        address owner;

        /// @dev The ID of the next loan that will be minted. Skips 0
        uint256 nextId;//should be 1

        uint256 unlocked;//should be 1


        //ERC20 fields
        string name;// = 'GammaSwap V1';
        string symbol;// = 'GAMA-V1';
        uint8 decimals;// = 18;
        uint256 totalSupply;
        mapping(address => uint) balanceOf;
        mapping(address => mapping(address => uint)) allowance;


        uint256 MINIMUM_LIQUIDITY;
    }

    function store() internal pure returns (GammaPoolStore storage _store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            _store.slot := position
        }
    }

    function init() internal {
        GammaPoolStore storage _store = store();
        _store.name = 'GammaSwap V1';
        _store.symbol = 'GAMA-V1';
        _store.decimals = 18;
        _store.factory = msg.sender;
        (_store.tokens, _store.protocol, _store.cfmm, _store.module) = IGammaPoolFactory(msg.sender).getParameters();
        _store.TOKEN_BALANCE = new uint[](_store.tokens.length);
        _store.CFMM_RESERVES = new uint[](_store.tokens.length);
        _store.accFeeIndex = 1;
        _store.lastFeeIndex = 1;
        _store.lastCFMMFeeIndex = 1;
        _store.LAST_BLOCK_NUMBER = block.number;
        _store.owner = msg.sender;
        _store.nextId = 1;
        _store.unlocked = 1;
        _store.MINIMUM_LIQUIDITY = 10**3;
    }

    function lockit() internal {
        GammaPoolStore storage _store = store();
        require(_store.unlocked == 1, 'LOCK');
        _store.unlocked = 0;
    }

    function unlockit() internal {
        store().unlocked = 1;
    }

    function createLoan() internal returns(uint256 tokenId) {
        GammaPoolStore storage _store = store();
        uint256 id = _store.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        _store.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            tokensHeld: new uint[](_store.tokens.length),
            heldLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: _store.accFeeIndex,
            blockNum: block.number
        });
    }
}
