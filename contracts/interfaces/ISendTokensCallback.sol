pragma solidity ^0.8.0;

interface ISendTokensCallback {
    function sendTokensCallback(uint[] calldata amounts) external;
}
