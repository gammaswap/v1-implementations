pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../contracts/test/TestVaultGammaPool.sol";
import "../../contracts/test/strategies/vault/TestVaultBaseStrategy.sol";

contract VaultGammaPoolTest is Test {

    TestVaultGammaPool vaultPool;
    TestVaultBaseStrategy vaultStrategy;

    function setUp() public {
        ICPMMGammaPool.InitializationParams memory params = ICPMMGammaPool.InitializationParams({
            protocolId: 1,
            factory: address(0),
            borrowStrategy: address(0),
            repayStrategy: address(0),
            rebalanceStrategy: address(0),
            shortStrategy: address(0),
            liquidationStrategy: address(0),
            batchLiquidationStrategy: address(0),
            viewer: address(0),
            externalRebalanceStrategy: address(0),
            externalLiquidationStrategy: address(0),
            cfmmFactory: address(0),
            cfmmInitCodeHash: bytes32(0)
        });

        vaultPool = new TestVaultGammaPool(params);
        vaultStrategy = new TestVaultBaseStrategy();
    }

    function testPoolRESERVED_BORROWED_INVARIANT() public {
        assertEq(vaultPool.getRESERVED_BORROWED_INVARIANT(),uint256(keccak256("RESERVED_BORROWED_INVARIANT")));
    }

    function testPoolRESERVED_LP_TOKENS() public {
        assertEq(vaultPool.getRESERVED_LP_TOKENS(),uint256(keccak256("RESERVED_LP_TOKENS")));
    }

    function testStrategyRESERVED_BORROWED_INVARIANT() public {
        assertEq(vaultStrategy.getRESERVED_BORROWED_INVARIANT(),uint256(keccak256("RESERVED_BORROWED_INVARIANT")));
    }

    function testStrategyRESERVED_LP_TOKENS() public {
        assertEq(vaultStrategy.getRESERVED_LP_TOKENS(),uint256(keccak256("RESERVED_LP_TOKENS")));
    }
}
