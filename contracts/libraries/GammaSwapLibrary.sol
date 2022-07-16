// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library GammaSwapLibrary {

    bytes4 private constant BALANCE_OF = bytes4(keccak256(bytes('balanceOf(address)')));
    bytes4 private constant TOTAL_SUPPLY = bytes4(keccak256(bytes('totalSupply()')));
    bytes4 private constant TRANSFER = bytes4(keccak256(bytes('transfer(address,uint256)')));

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'GSL: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GSL: ZERO_ADDRESS');
    }

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check TODO: This should probably be library function
    function balanceOf(address token, address addr) internal view returns (uint256) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(BALANCE_OF, addr));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get the pool's balance of token0
    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    /// check TODO: This should probably be library function
    function totalSupply(address token) internal view returns (uint256) {
        (bool success, bytes memory data) =
        token.staticcall(abi.encodeWithSelector(TOTAL_SUPPLY));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function transfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(TRANSFER, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'GSL.transfer: TRANSFER_FAILED');
    }
}