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
        uint256 borrowRate;
        uint256 accFeeIndex;
        uint256 lastFeeIndex;
        uint256 lastCFMMFeeIndex;
        uint256 lastCFMMInvariant;
        uint256 lastCFMMTotalSupply;
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

    function store() internal pure returns (GammaPoolStore storage store) {
        bytes32 position = STRUCT_POSITION;
        assembly {
            store.slot := position
        }
    }

    function init() internal {
        GammaPoolStore storage store = store();
        store.name = 'GammaSwap V1';
        store.symbol = 'GAMA-V1';
        store.decimals = 18;
        store.factory = msg.sender;
        (store.tokens, store.protocol, store.cfmm, store.module) = IGammaPoolFactory(msg.sender).getParameters();
        store.TOKEN_BALANCE = new uint[](store.tokens.length);
        store.accFeeIndex = 1;
        store.lastFeeIndex = 1;
        store.lastCFMMFeeIndex = 1;
        store.LAST_BLOCK_NUMBER = block.number;
        store.owner = msg.sender;
        store.nextId = 1;
        store.unlocked = 1;
        store.MINIMUM_LIQUIDITY = 10**3;
    }

    function lockit() internal {
        GammaPoolStore storage store = store();
        require(store.unlocked == 1, 'LOCK');
        store.unlocked = 0;
    }

    function unlockit() internal {
        store().unlocked = 1;
    }

    function createLoan() internal returns(uint256 tokenId) {
        GammaPoolStore storage store = store();
        uint256 id = store.nextId++;
        tokenId = uint256(keccak256(abi.encode(msg.sender, address(this), id)));

        store.loans[tokenId] = Loan({
            id: id,
            poolId: address(this),
            tokensHeld: new uint[](store.tokens.length),
            heldLiquidity: 0,
            liquidity: 0,
            lpTokens: 0,
            rateIndex: store.accFeeIndex,
            blockNum: block.number
        });
    }
}
