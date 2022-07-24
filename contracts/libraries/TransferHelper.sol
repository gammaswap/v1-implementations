// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library TransferHelper {

    bytes4 private constant TRANSFER = bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes4 private constant TRANSFER_FROM = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    bytes4 private constant APPROVE = bytes4(keccak256(bytes('approve(address,uint256)')));

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(TRANSFER_FROM, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF');
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST');
    }

    function safeApprove(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(APPROVE, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'SA');
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'STE');
    }
}