// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library GammaSwapLibrary {

    error ST_Fail();
    error STF_Fail();

    function balanceOf(IERC20 token, address addr) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(token).staticcall(abi.encodeWithSelector(token.balanceOf.selector, addr));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function totalSupply(IERC20 token) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(token).staticcall(abi.encodeWithSelector(token.totalSupply.selector));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        (bool success, bytes memory data) = address(token).call(abi.encodeWithSelector(token.transfer.selector, to, value));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert ST_Fail();
        }
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
        address(token).call(abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert STF_Fail();
        }
    }
}