// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.17;

import "../../../strategies/balancer/base/BalancerBaseStrategy.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TestBalancerBaseStrategy is BalancerBaseStrategy {

    using LibStorage for LibStorage.Storage;

    event DepositToCFMM(address cfmm, address to, uint256 liquidity);
    event WithdrawFromCFMM(address cfmm, address to, uint256[] amounts);

    constructor(uint64 _baseRate, uint80 _factor, uint80 _maxApy, uint256 _weight0)
        BalancerBaseStrategy(1e19, 2252571, _baseRate, _factor, _maxApy, _weight0) {
    }

    function initialize(address cfmm, address[] calldata tokens, uint8[] calldata decimals, bytes32 _poolId, address _vault) external virtual {
        s.initialize(msg.sender, cfmm, 1, tokens, decimals);

        // Store the PoolId in the storage contract
        s.setBytes32(uint256(StorageIndexes.POOL_ID), _poolId);
        
        s.setAddress(uint256(StorageIndexes.VAULT), _vault);

        // Store the scaling factors for the CFMM in the storage contract
        s.setUint256(uint256(StorageIndexes.SCALING_FACTOR0), 10 ** (18 - decimals[0]));
        s.setUint256(uint256(StorageIndexes.SCALING_FACTOR1), 10 ** (18 - decimals[1]));
    }

    function getCFMM() public virtual view returns(address) {
        return s.cfmm;
    }

    function getCFMMReserves() public virtual view returns(uint128[] memory) {
        return s.CFMM_RESERVES;
    }

    function testGetPoolId(address) public virtual view returns(bytes32) {
        return getPoolId();
    }

    function testGetVault(address) public virtual view returns(address) {
        return getVault();
    }

    function testGetSwapFeePercentage(address cfmm) public virtual view returns(uint256) {
        return getSwapFeePercentage(cfmm);
    }

    function testGetPoolReserves(address) public view returns(uint256[] memory _reserves) {
        (,_reserves,) = IVault(getVault()).getPoolTokens(getPoolId());
    }

    function testGetWeights() public virtual view returns(uint256[] memory _weights) {
        _weights = new uint256[](2);
        _weights[0] = weight0;
        _weights[1] = weight1;
    }

    function testGetScalingFactors() public virtual view returns(uint256[] memory factors) {
        factors = new uint256[](2);
        (factors[0], factors[1]) = getScalingFactors();
    }

    function testGetTokens(address) public virtual view returns(address[] memory) {
        return s.tokens;
    }

    function testUpdateReserves() public virtual {
        updateReserves(s.cfmm);
    }

    function testDepositToCFMM(address cfmm, uint256[] memory amounts, address to) public virtual {
        uint256 liquidity = depositToCFMM(cfmm, to, amounts);
        emit DepositToCFMM(cfmm, to, liquidity);
    }

    function testWithdrawFromCFMM(address cfmm, uint256 amount, address to) public virtual {
        uint256[] memory amounts = withdrawFromCFMM(cfmm, to, amount);
        emit WithdrawFromCFMM(cfmm, to, amounts);
    }

    function testCalcInvariant(address cfmm, uint128[] memory amounts) public virtual view returns(uint256) {
        return calcInvariant(cfmm, amounts);
    }
}
