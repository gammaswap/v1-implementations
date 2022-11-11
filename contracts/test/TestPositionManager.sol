// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@gammaswap/v1-periphery/contracts/interfaces/ISendTokensCallback.sol";
import "@gammaswap/v1-periphery/contracts/libraries/TransferHelper.sol";
import "@gammaswap/v1-core/contracts/libraries/AddressCalculator.sol";
import "./strategies/TestShortStrategy.sol";

contract TestPositionManager is ISendTokensCallback {
    event Transfer(address indexed from, address indexed to, uint256 value);

    event Deposit(address indexed caller, address indexed to, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed to, address indexed from, uint256 assets, uint256 shares);

    event PoolUpdated(uint256 lpTokenBalance, uint256 lpTokenBorrowed, uint256 lastBlockNumber, uint256 accFeeIndex,
        uint256 lastFeeIndex, uint256 lpTokenBorrowedPlusInterest, uint256 lpInvariant, uint256 borrowedInvariant);

    event DepositReserve(address indexed pool, uint256 reservesLen, uint256[] reserves, uint256 shares);

    address public immutable factory;
    address public immutable pool;
    address public immutable cfmm;
    uint24 public immutable protocol;

    constructor(address _factory, address _pool, address _cfmm, uint24 _protocol) {
        factory = _factory;
        pool = _pool;
        cfmm = _cfmm;
        protocol = _protocol;
    }

    function getGammaPoolAddress(address cfmm, uint24 protocol) internal virtual view returns(address) {
        return AddressCalculator.calcAddress(factory, AddressCalculator.getGammaPoolKey(cfmm, protocol));
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
            abi.encode(SendTokensCallbackData({cfmm: cfmm, protocol: protocol, payer: msg.sender})));
        emit DepositReserve(pool, reserves.length, reserves, shares);
    }

    function send(address token, address sender, address to, uint256 amount) internal {
        if (sender == address(this)) {
            // send with tokens already in the contract
            TransferHelper.safeTransfer(token, to, amount);
        } else {
            // pull transfer
            TransferHelper.safeTransferFrom(token, sender, to, amount);
        }
    }
}
