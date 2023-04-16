pragma solidity ^0.8.0;

import "@gammaswap/v1-core/contracts/GammaPoolFactory.sol";

import "./UniswapSetup.sol";
import "./TokensSetup.sol";
import "../../../contracts/pools/CPMMGammaPool.sol";
import "../../../contracts/strategies/cpmm/CPMMLiquidationStrategy.sol";
import "../../../contracts/strategies/cpmm/CPMMShortStrategy.sol";

contract CPMMGammaSwapSetup is UniswapSetup, TokensSetup {

    GammaPoolFactory factory;

    CPMMLongStrategy longStrategy;
    CPMMShortStrategy shortStrategy;
    CPMMLiquidationStrategy liquidationStrategy;
    CPMMGammaPool protocol;
    CPMMGammaPool pool;

    address cfmm;
    address owner;

    function initCPMMGammaSwap() public {
        owner = address(this);
        super.initTokens();
        super.initUniswap(owner, address(weth));

        factory = new GammaPoolFactory(owner);

        uint16 PROTOCOL_ID = 1;
        uint64 baseRate = 1e16;
        uint80 factor = 4 * 1e16;
        uint80 maxApy = 75 * 1e16;
        uint256 maxTotalApy = 1e19;

        longStrategy = new CPMMLongStrategy(8000, maxTotalApy, 2252571, 0, 997, 1000, baseRate, factor, maxApy);
        shortStrategy = new CPMMShortStrategy(maxTotalApy, 2252571, baseRate, factor, maxApy);
        liquidationStrategy = new CPMMLiquidationStrategy(9500, 9750, maxTotalApy, 2252571, 997, 1000, baseRate, factor, maxApy);

        bytes32 cfmmHash = hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'; // UniV2Pair init_code_hash
        protocol = new CPMMGammaPool(PROTOCOL_ID, address(factory), address(longStrategy), address(shortStrategy),
            address(liquidationStrategy), address(uniFactory), cfmmHash);

        factory.addProtocol(address(protocol));

        address[] memory tokens = new address[](2);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);

        cfmm = createPair(tokens[0], tokens[1]);

        pool = CPMMGammaPool(factory.createPool(PROTOCOL_ID, cfmm, tokens, new bytes(0)));
    }

}
