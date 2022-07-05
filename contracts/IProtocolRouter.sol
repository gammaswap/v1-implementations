pragma solidity ^0.8.0;
pragma abicoder v2;

contract IProtocolRouter {
    struct AddLiquidityParams {
        address tokenA;
        address tokenB;
        uint amountADesired;
        uint amountBDesired;
        uint amountAMin;
        uint amountBMin;
        address to;
        uint protocolId;
        uint deadline;
        address gammaPool;
    }/**/


}
