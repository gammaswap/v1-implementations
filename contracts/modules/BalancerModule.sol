// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../libraries/PoolAddress.sol";
import "../interfaces/IProtocolModule.sol";

contract BalancerModule is IProtocolModule {

    address public immutable override factory;//protocol factory
    address public immutable override protocolFactory;//protocol factory
    uint24 public override protocol;

    constructor(address _factory, address _protocolFactory) {
        factory = _factory;
        protocolFactory = _protocolFactory;
        protocol = 3;
    }

    function at(address _addr) internal view returns (bytes memory o_code) {
        assembly {
        // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
        // allocate output byte array - this could also be done without assembly
        // by using o_code = new bytes(size)
            o_code := mload(0x40)
        // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
        // store length in memory
            mstore(o_code, size)
        // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }

    //TODO: Not finished
    function validateCFMM(address[] calldata _tokens, address _cfmm)  external view override returns(address[] memory tokens, bytes32 key){
        /*require(type(BPool).bytecode == at(params.cfmm), 'BalancerModule.validateParams: INVALID_PROTOCOL_FOR_CFMM');//This check is probably way too expensive
        tokens = BPool(params.cfmm).getFinalTokens();//In the case of Balancer we would request the tokens here. With Balancer we can probably check the bytecode of the contract to verify it is from balancer
        salt = 0;/**/
    }

    function calcBorrowRate(uint256 lpBalance, uint256 lpBorrowed) external virtual override view returns(uint256 borrowRate) {
        return 0;
    }

    function getKey(address _cfmm) external view override returns(bytes32 key) {
    }

    function getCFMMTotalInvariant(address cfmm) external view virtual override returns(uint256 invariant) {
        invariant = uint160(cfmm);
    }

    function getCFMMYield(address cfmm, uint256 prevInvariant, uint256 prevTotalSupply) external view virtual override returns(uint256 lastFeeIndex, uint256 lastInvariant, uint256 lastTotalSupply) {
    }

    // **** ADD LIQUIDITY ****
    function addLiquidity(
        address cfmm,
        uint[] calldata amountsDesired,
        uint[] calldata amountsMin
    ) external virtual override returns (uint[] memory amounts, address payee) {
        // create the pair if it doesn't exist yet
        /*amountA = 0;
        amountB = 0;
        cfmm = address(0);/**/
    }

    function mint(address cfmm, uint[] calldata amounts) external virtual override returns(uint liquidity) {
    }

    function burn(address cfmm, address to, uint256 amount) external virtual override returns(uint[] memory amounts) {
        /*address gammaPool = PoolAddress.computeAddress(factory, PoolAddress.getPoolKey(cfmm, protocol));
        require(gammaPool == msg.sender, "UniswapV2Module.burn: FORBIDDEN");
        IRemoveLiquidityCallback(gammaPool).removeLiquidityCallback(address(this), amount);
        address[] _tokens = IGammaPool(gammaPool).tokens();
        amounts = new uint[](_tokens.length);
        IBPoolMinimal(cfmm).exitPool(amount, amounts);
        for (uint i = 0; i < _tokens.length; i++) {
            amounts[i] = GammaSwapLibrary.balanceOf(_tokens[i], address(this));
            GammaSwapLibrary.transfer(_tokens[i], to, amounts[i]);
        }/**/
    }

    function calcInvariant(address cfmm, uint[] calldata amounts) external virtual override view returns(uint) {
        return 0;//return Math.sqrt(amounts[0] * amounts[1]);//This is wrong for balancer. We must check what the weights should be by asking the cfmm. Or maybe we should pass the expected ratio here.
        //probably not because this weighting is assuming geometric mean market maker. We could instead use some other function or a summation.
    }

    function checkCollateral(address cfmm, uint[] calldata tokensHeld, uint256 invariantBorrowed) external virtual override view returns(bool) {
        //Must calculate the max loss price of tokensHeld to see how far are we covered. If the liquidity we've provided is sufficient
        //Must use that formula that checks the ratio of the tokensHeld and calculates the maxLoss price and what the liquidity is at that price to protect against flash loan attacks
        return true;
    }

    function convertLiquidityToAmounts(address cfmm, uint256 liquidity) external virtual override view returns(uint256[] memory amounts) {
        /*(uint reserveA, uint reserveB,) = IUniswapV2PairMinimal(cfmm).getReserves();
        amounts = new uint256[](2);
        uint256 cfmmInvariant = Math.sqrt(reserveA * reserveB);
        amounts[0] = liquidity * reserveA / cfmmInvariant;
        amounts[1] = liquidity * reserveB / cfmmInvariant;/**/
    }
}
