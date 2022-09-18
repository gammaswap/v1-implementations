// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

library GammaSwapLibrary {

    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes('balanceOf(address)')));
    bytes4 private constant TOTAL_SUPPLY = bytes4(keccak256(bytes('totalSupply()')));
    bytes4 private constant TRANSFER = bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes4 private constant TRANSFER_FROM = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));

    function balanceOf(address token, address addr) internal view returns (uint256) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(BALANCE_OF, addr));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function totalSupply(address token) internal view returns (uint256) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(TOTAL_SUPPLY));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'ST_FAIL');
    }

    function safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(TRANSFER_FROM, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'STF_FAIL');
    }
}