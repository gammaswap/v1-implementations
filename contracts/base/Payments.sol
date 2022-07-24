// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import '../interfaces/IPayments.sol';
import '../interfaces/external/IWETH.sol';
import '../interfaces/external/IERC20.sol';
import '../libraries/TransferHelper.sol';

abstract contract Payments is IPayments {

    address public immutable override WETH;

    constructor(address _WETH) {
        WETH = _WETH;
    }

    receive() external payable {
        require(msg.sender == WETH, 'NOT_WETH');
    }

    function unwrapWETH(uint256 minAmt, address to) public payable override {
        uint256 wethBal = IERC20(WETH).balanceOf(address(this));
        require(wethBal >= minAmt, 'wethBal < minAmt');

        if (wethBal > 0) {
            IWETH(WETH).withdraw(wethBal);
            TransferHelper.safeTransferETH(to, wethBal);
        }
    }

    function clearToken(address token, uint256 minAmt, address to) public payable override {
        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        require(tokenBal >= minAmt, 'tokenBal < minAmt');

        if (tokenBal > 0) TransferHelper.safeTransfer(token, to, tokenBal);
    }

    function refundETH() external payable override {
        if (address(this).balance > 0) TransferHelper.safeTransferETH(msg.sender, address(this).balance);
    }

    function pay(address token, address payer, address to, uint256 amount) internal {
        if (token == WETH && address(this).balance >= amount) {
            // pay with WETH
            IWETH(WETH).deposit{value: amount}(); // wrap only what is needed to pay
            TransferHelper.safeTransfer(WETH, to, amount);
        } else if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, to, amount);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, to, amount);
        }
    }
}