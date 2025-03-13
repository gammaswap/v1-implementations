pragma solidity ^0.8.0;

import "../pools/VaultGammaPool.sol";

contract TestVaultGammaPool is VaultGammaPool {
    constructor(InitializationParams memory params) VaultGammaPool(params) {
    }

    function getRESERVED_LP_TOKENS() external virtual pure returns(uint256) {
        return RESERVED_LP_TOKENS();
    }

    function getRESERVED_BORROWED_INVARIANT() external virtual pure returns(uint256) {
        return RESERVED_BORROWED_INVARIANT();
    }

    function reserveLPTokens(uint256 tokenId, uint256 lpTokens, bool isReserve) external virtual override returns(uint256) {
        return 0;
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm, bytes calldata) external virtual override view returns(address[] memory) {
        return new address[](0);
    }
}
