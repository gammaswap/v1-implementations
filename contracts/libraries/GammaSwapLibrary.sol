// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Library used to perform common ERC20 transactions
/// @author Daniel D. Alcarraz
/// @dev Library performs transfers and views ERC20 state fields
library GammaSwapLibrary {

    error ST_Fail();
    error STF_Fail();

    /// @dev Check the ERC20 balance of an address
    /// @param _token - address of ERC20 token we're checking the balance of
    /// @param _address - Ethereum address we're checking for balance of ERC20 token
    /// @return balanceOf - amount of _token held in _address
    function balanceOf(IERC20 _token, address _address) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(_token).staticcall(abi.encodeWithSelector(_token.balanceOf.selector, _address));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Get how much of an ERC20 token is in existence (minted)
    /// @param _token - address of ERC20 token we're checking the total minted amount of
    /// @return totalSupply - total amount of _token that is in existence (minted and not burned)
    function totalSupply(IERC20 _token) internal view returns (uint256) {
        (bool success, bytes memory data) =
        address(_token).staticcall(abi.encodeWithSelector(_token.totalSupply.selector));
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    /// @dev Safe transfer any ERC20 token, only used internally
    /// @param _token - address of ERC20 token that will be transferred
    /// @param _to - destination address where ERC20 token will be sent to
    /// @param _amount - quantity of ERC20 token to be transferred
    function safeTransfer(IERC20 _token, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) = address(_token).call(abi.encodeWithSelector(_token.transfer.selector, _to, _amount));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert ST_Fail();
        }
    }

    /// @dev Moves `amount` of ERC20 token `_token` from `_from` to `_to` using the allowance mechanism. `_amount` is then deducted from the caller's allowance.
    /// @param _token - address of ERC20 token that will be transferred
    /// @param _from - address sending _token (not necessarily caller's address)
    /// @param _to - address receiving _token
    /// @param _amount - amount of _token being sent
    function safeTransferFrom(IERC20 _token, address _from, address _to, uint256 _amount) internal {
        (bool success, bytes memory data) =
        address(_token).call(abi.encodeWithSelector(_token.transferFrom.selector, _from, _to, _amount));
        if(!(success && (data.length == 0 || abi.decode(data, (bool))))) {
            revert STF_Fail();
        }
    }
}