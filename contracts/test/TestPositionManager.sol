// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-periphery/contracts/interfaces/ISendTokensCallback.sol";
import "@gammaswap/v1-periphery/contracts/libraries/TransferHelper.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "./strategies/base/TestShortStrategy.sol";

contract TestPositionManager is ISendTokensCallback {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);

    event DepositReserve(address indexed pool, uint256 reservesLen, uint256[] reserves, uint256 shares);

    address public immutable pool;
    address public immutable cfmm;
    uint16 public immutable protocolId;

    constructor(address _pool, address _cfmm, uint16 _protocolId) {
        pool = _pool;
        cfmm = _cfmm;
        protocolId = _protocolId;
    }

    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external virtual override {
        SendTokensCallbackData memory decoded = abi.decode(data, (SendTokensCallbackData));
        for(uint i = 0; i < tokens.length; i++) {
            if(amounts[i] > 0) {
                if(amounts[i] % 2 == 0) {
                    send(tokens[i], decoded.payer, payee, amounts[i]);
                } else {
                    send(tokens[i], decoded.payer, payee, amounts[i] + 1);
                }
            }
        }
    }

    function depositReserves(address to, uint256[] calldata amountsDesired, uint256[] calldata amountsMin) external virtual returns(uint256[] memory reserves, uint256 shares) {
        (reserves, shares) = TestShortStrategy(pool)._depositReserves(to, amountsDesired, amountsMin,
            abi.encode(SendTokensCallbackData({cfmm: cfmm, protocolId: protocolId, payer: msg.sender})));
        emit DepositReserve(pool, reserves.length, reserves, shares);
    }

    function send(address token, address sender, address to, uint256 amount) internal {
        if (sender == address(this)) {
            // send with tokens already in the contract
            TransferHelper.safeTransfer(IERC20(token), to, amount);
        } else {
            // pull transfer
            TransferHelper.safeTransferFrom(IERC20(token), sender, to, amount);
        }
    }
}
