// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./interfaces/IGammaPoolFactory.sol";
import "./interfaces/strategies/ILongStrategy.sol";
import "./interfaces/strategies/IShortStrategy.sol";
import "./interfaces/IGammaPool.sol";
import "./libraries/storage/GammaPoolStorage.sol";

contract GammaPool is IGammaPool {

    modifier lock() {
        GammaPoolStorage.lockit();
        _;
        GammaPoolStorage.unlockit();
    }

    constructor() {
        GammaPoolStorage.init();
    }

    function createLoan() external virtual lock returns(uint tokenId) {
        tokenId = GammaPoolStorage.createLoan();
    }

    function loans(uint256 tokenId) external virtual view returns (uint256 id, address poolId,
        uint256[] memory tokensHeld, uint256 liquidity, uint256 rateIndex, uint256 blockNum) {
        GammaPoolStorage.Loan memory loan = GammaPoolStorage.store().loans[tokenId];
        return (loan.id, loan.poolId, loan.tokensHeld, loan.liquidity, loan.rateIndex, loan.blockNum);
    }

    /*****SHORT*****/
    function _mint(address to) external virtual override returns(uint256 liquidity) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSignature("mint(address)", to));
        require(success);
        return abi.decode(result, (uint256));

    }

    function _burn(address to) external virtual override returns (uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSignature("burn(address)", to));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function _addLiquidity(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin, bytes calldata data) external virtual override returns(uint256[] memory amounts){
        (bool success, bytes memory result) = GammaPoolStorage.store().shortStrategy.delegatecall(abi.encodeWithSignature("addLiquidity(address,uint256[],uint256[],bytes)", to, amountsDesired, amountsMin, data));
        require(success);
        return abi.decode(result, (uint256[]));
    }


    /*****LONG*****/
    function _increaseCollateral(uint256 tokenId) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("increaseCollateral(uint256)", tokenId));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function _decreaseCollateral(uint256 tokenId, uint256[] calldata amounts, address to) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("decreaseCollateral(uint256,uint256[],address)", tokenId, amounts, to));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function _borrowLiquidity(uint256 tokenId, uint256 lpTokens) external virtual override returns(uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("borrowLiquidity(uint256,uint256)", tokenId, lpTokens));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function _repayLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256 liquidityPaid, uint256 lpTokensPaid, uint256[] memory amounts) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("repayLiquidity(uint256,uint256)", tokenId, liquidity));
        require(success);
        return abi.decode(result, (uint256,uint256,uint256[]));
    }

    function _rebalanceCollateral(uint256 tokenId, int256[] calldata deltas) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("rebalanceCollateral(uint256,int256[])", tokenId, deltas));
        require(success);
        return abi.decode(result, (uint256[]));
    }

    function _rebalanceCollateralWithLiquidity(uint256 tokenId, uint256 liquidity) external virtual override returns(uint256[] memory tokensHeld) {
        (bool success, bytes memory result) = GammaPoolStorage.store().longStrategy.delegatecall(abi.encodeWithSignature("rebalanceCollateralWithLiquidity(uint256,uint256)", tokenId, liquidity));
        require(success);
        return abi.decode(result, (uint256[]));
    }
}
