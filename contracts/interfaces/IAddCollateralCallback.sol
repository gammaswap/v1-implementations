// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface IAddCollateralCallback {
    struct AddCollateralCallbackData {
        bytes32 poolKey;
        address payer;
    }

    function addCollateralCallback(
        address[] calldata tokens,
        uint[] calldata amounts,
        bytes calldata data
    ) external;
}
