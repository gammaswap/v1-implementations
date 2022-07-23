pragma solidity ^0.8.0;

import "./BaseModule.sol";

import "../libraries/Math.sol";
import "../libraries/PoolAddress.sol";
import "../libraries/TransferHelper.sol";
import "../libraries/UniswapV2Storage.sol";
import "../interfaces/external/IUniswapV2PairMinimal.sol";

abstract contract UniswapV2BaseModule is BaseModule {

    /*function isContract(address account) internal view returns (bool) {
        // According to EIP-1052, 0x0 is the value returned for not-yet created accounts
        // and 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470 is returned
        // for accounts without code, i.e. keccak256('')
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        // solhint-disable-next-line no-inline-assembly
        assembly { codehash := extcodehash(account) }
        return (codehash != accountHash && codehash != 0x0);
    }

    function validateCFMM(address[] calldata _tokens, address _cfmm) external view returns(address[] memory tokens, bytes32 key){
        require(isContract(_cfmm) == true, 'not contract');
        tokens = new address[](2);//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        (tokens[0], tokens[1]) = _tokens[0] < _tokens[1] ? (_tokens[0], _tokens[1]) : (_tokens[1], _tokens[0]);//For Uniswap and its clones the user passes the parameters
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        require(_cfmm == PoolAddress.computeAddress(store.protocolFactory,keccak256(abi.encodePacked(tokens[0], tokens[1])),store.initCodeHash), 'bad protocol');
        key = PoolAddress.getPoolKey(_cfmm, store.protocol);
    }/**/

    function updateReserves(GammaPoolStorage.GammaPoolStore storage store) internal virtual override {
        (store.CFMM_RESERVES[0], store.CFMM_RESERVES[1],) = IUniswapV2PairMinimal(store.cfmm).getReserves();
    }

    //Protocol specific functionality
    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) internal virtual override view returns(uint256) {
        UniswapV2Storage.UniswapV2Store storage store = UniswapV2Storage.store();
        uint256 utilizationRate = (lpBorrowed * store.ONE) / (lpBalance + lpBorrowed);
        if(utilizationRate <= store.OPTIMAL_UTILIZATION_RATE) {
            uint256 variableRate = (utilizationRate * store.SLOPE1) / store.OPTIMAL_UTILIZATION_RATE;
            return (store.BASE_RATE + variableRate);
        } else {
            uint256 utilizationRateDiff = utilizationRate - store.OPTIMAL_UTILIZATION_RATE;
            uint256 variableRate = (utilizationRateDiff * store.SLOPE2) / (store.ONE - store.OPTIMAL_UTILIZATION_RATE);
            return(store.BASE_RATE + store.SLOPE1 + variableRate);
        }
    }

    function depositToCFMM(address cfmm, uint256[] memory amounts, address to) internal virtual override returns(uint256) {
        return IUniswapV2PairMinimal(cfmm).mint(to);
    }

    //TODO: Can be delegated
    function withdrawFromCFMM(address cfmm, address to, uint256 amount) internal virtual override returns(uint[] memory amounts) {
        TransferHelper.safeTransfer(cfmm, cfmm, amount);
        amounts = new uint[](2);
        (amounts[0], amounts[1]) = IUniswapV2PairMinimal(cfmm).burn(to);/**/
    }

    function calcInvariant(address cfmm, uint[] memory amounts) internal virtual override view returns(uint256) {
        return Math.sqrt(amounts[0] * amounts[1]);
    }
}
