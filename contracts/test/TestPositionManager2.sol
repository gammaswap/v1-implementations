pragma solidity 0.8.4;

import "@gammaswap/v1-periphery/contracts/PositionManager.sol";

contract TestPositionManager2 is PositionManager {
    constructor(address _factory, address _WETH) PositionManager(_factory, _WETH) {
    }

    function depositNoPull(DepositWithdrawParams calldata params) external virtual override isExpired(params.deadline) returns(uint256 shares) {
        address gammaPool = getGammaPoolAddress(params.cfmm, params.protocolId);
        send(params.cfmm, msg.sender, gammaPool, params.lpTokens); // send lp tokens to pool
        shares = IGammaPool(gammaPool).depositNoPull(params.to);
        emit DepositNoPull(gammaPool, shares);
    }

    function increaseCollateral(AddRemoveCollateralParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns(uint128[] memory tokensHeld) {
        address gammaPool = getGammaPoolAddress(params.cfmm, params.protocolId);
        tokensHeld = increaseCollateral(gammaPool, params.tokenId, params.amounts);
        logLoan(gammaPool, params.tokenId, msg.sender);
    }

    function borrowLiquidity(BorrowLiquidityParams calldata params) external virtual override isAuthorizedForToken(params.tokenId) isExpired(params.deadline) returns (uint256[] memory amounts) {
        address gammaPool = getGammaPoolAddress(params.cfmm, params.protocolId);
        amounts = borrowLiquidity(gammaPool, params.tokenId, params.lpTokens, params.minBorrowed);
        logLoan(gammaPool, params.tokenId, msg.sender);
    }
}
