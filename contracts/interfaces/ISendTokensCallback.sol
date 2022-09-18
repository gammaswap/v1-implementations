// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface ISendTokensCallback {

    struct SendTokensCallbackData {
        address payer;
        address cfmm;
        uint24 protocol;
    }

    function sendTokensCallback(address[] calldata tokens, uint256[] calldata amounts, address payee, bytes calldata data) external;
}
