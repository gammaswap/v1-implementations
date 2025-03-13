// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import "../../../strategies/vault/base/VaultBaseStrategy.sol";

contract TestVaultBaseStrategy is VaultBaseStrategy {

    constructor() {
    }

    function getRESERVED_LP_TOKENS() external virtual pure returns(uint256) {
        return RESERVED_LP_TOKENS();
    }

    function getRESERVED_BORROWED_INVARIANT() external virtual pure returns(uint256) {
        return RESERVED_BORROWED_INVARIANT();
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant, address paramsStore, address pool) public
        virtual override view returns(uint256, uint256, uint256, uint256) {
        return (0,0,0,0);
    }

    function validateParameters(bytes calldata _data) external virtual override view returns(bool) {
        return false;
    }

    function syncCFMM(address cfmm) internal virtual override {
    }

    function getReserves(address cfmm) internal virtual override view returns(uint128[] memory) {
        return new uint128[](0);
    }

    function getLPReserves(address cfmm, bool isLatest) internal virtual override view returns(uint128[] memory) {
        return new uint128[](0);
    }

    function calcInvariant(address cfmm, uint128[] memory amounts) internal virtual override view returns(uint256) {
        return 0;
    }

    function depositToCFMM(address cfmm, address to, uint256[] memory amounts) internal virtual override returns(uint256) {
        return 0;
    }

    function withdrawFromCFMM(address cfmm, address to, uint256 lpTokens) internal virtual override returns(uint256[] memory) {
        return new uint256[](0);
    }

    function maxTotalApy() internal virtual override view returns(uint256) {
        return 0;
    }

    function blocksPerYear() internal virtual override view returns(uint256) {
        return 0;
    }
}
