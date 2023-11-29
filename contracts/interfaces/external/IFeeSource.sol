pragma solidity ^0.8.0;

interface IFeeSource {
    function gsFee() external view returns(uint8);
}
