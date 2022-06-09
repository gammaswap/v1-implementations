 import { Contract, constants, BigNumber, utils, providers } from 'ethers';
 import { expandTo18Decimals, mineBlock, encodePrice, sqrt } from './shared/utilities';
 import { poolFixture } from './shared/fixtures';

 const Web3 = require("web3");
 const web3 = new Web3("ws://localhost:7545");

 require('chai').use(require('chai-as-promised')).should();

 const url = "http://localhost:7545";
 const provider = new providers.JsonRpcProvider(url);

 contract('PositionManager', (accounts) => {
     //let token;
     console.log(accounts[0]);

     //let factory;
     let token0;
     let token1;
     let token2;
     let pool;
     let uniPair;
     let posManager;
     let uniRouter;
     beforeEach(async () => {
        const fixture = await poolFixture(provider, accounts[0]);
        //factory = fixture.factory;
         token0 = fixture.token0;
         token1 = fixture.token1;
         token2 = fixture.token2;
         pool = fixture.pool;
         uniPair = fixture.uniPair;
         posManager = fixture.posManager;
         uniRouter = fixture.uniRouter;
     });

     describe('PositionManager', () => {
         async function setUp() {
             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);
             await addToUniLiquidity(token0Amount, token1Amount, accounts[1]);
             await addLiquidity(token0Amount, token1Amount, accounts[1]);
             await addLiquidity(token0Amount, token1Amount, accounts[0]);
         }

         async function addToUniLiquidity(token0Amount, token1Amount, acct) {
             await token0.transfer(uniPair.address, token0Amount);
             await token1.transfer(uniPair.address, token1Amount);
             const _tx = await uniPair.mint(acct, { from: accounts[0]});
             //const tx = await _tx.wait();
         }

         async function addLiquidity(token0Amount, token1Amount, acct) {
             await token0.approve(pool.address, constants.MaxUint256);
             await token1.approve(pool.address, constants.MaxUint256);
             const _tx = await pool.addLiquidity(token0Amount, token1Amount, 0, 0, acct, { from: accounts[0]});
             //const tx = await _tx.wait();
         }

         async function openPosition(amount0, amount1, liquidity, acct) {
             await token0.approve(posManager.address, constants.MaxUint256);
             await token1.approve(posManager.address, constants.MaxUint256);
             const tx = await posManager.openPosition(token0.address, token1.address, amount0, amount1, liquidity, acct);
         }

         async function increaseCollateral(tokenId, amount0, amount1, acct) {
             await token0.approve(posManager.address, constants.MaxUint256);
             await token1.approve(posManager.address, constants.MaxUint256);
             const tx = await posManager.increaseCollateral(tokenId, amount0, amount1, { from: acct});
         }

         /*it('burn::success', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(32), token1Amount.mul(32), accounts[0]);

             await openPosition(token0Amount.mul(1),token1Amount.mul(1), liquidity, accounts[0]);

             await posManager.decreasePosition(1,liquidity.mul(2));

             const pos = await posManager.positions(1);

             await posManager.decreaseCollateral(1, pos.tokensHeld0, pos.tokensHeld1, accounts[0]);

             await posManager.burn(1);

             await posManager.positions(1).should.be.rejectedWith('PositionManager: INVALID_TOKEN_ID');
          });/**/

         /*it('burn::failNotCleared', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(32), token1Amount.mul(32), accounts[0]);
             await addLiquidity(token0Amount.mul(2), token1Amount.mul(2), accounts[0]);

             await openPosition(token0Amount.mul(1),token1Amount.mul(1), liquidity, accounts[0]);

             await posManager.burn(1).should.be.rejectedWith('PositionManager: NOT_CLEARED');

             await posManager.decreasePosition(1, liquidity.mul(2));
             const pos = await posManager.positions(1);
             await posManager.burn(1).should.be.rejectedWith('PositionManager: NOT_CLEARED');

             await posManager.decreaseCollateral(1, pos.tokensHeld0, 0, accounts[0]);
             await posManager.burn(1).should.be.rejectedWith('PositionManager: NOT_CLEARED');//only token1

             await increaseCollateral(1, token0Amount, 0, accounts[0]);

             await posManager.decreaseCollateral(1, 0, pos.tokensHeld1, accounts[0]);
             await posManager.burn(1).should.be.rejectedWith('PositionManager: NOT_CLEARED');//only token0
         });/**/

         /*it('swapPositionTokensForExactTokens::sell', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(32), token1Amount.mul(32), accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
                 token0: token0.address,
                 token1: token1.address,
                 liquidity: liquidity,
                 recipient: accounts[0],
                 deadline: constants.MaxUint256
             });

             await res.wait();

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));

             const res0 = await posManager.mint({
                 token0: token0.address,
                 token1: token1.address,
                 liquidity: liquidity,
                 recipient: accounts[1],
                 deadline: constants.MaxUint256
             });

             await res0.wait();

             const pos = await posManager.positions(1);

             const token0Bal = await posManager.tokenBalances(token0.address);
             const token1Bal = await posManager.tokenBalances(token1.address);

             const ONE = expandTo18Decimals(1);

             const resp = await posManager
             .swapPositionTokensForExactTokens({ tokenId: 1, amount: ONE, side: false, slippage: constants.MaxUint256, deadline: constants.MaxUint256 });

             await resp.wait();

             const pos0 = await posManager.positions(1);

             assert.equal(BigNumber.from(pos0.tokensHeld0.toString()).lt(BigNumber.from(pos.tokensHeld0.toString())), true);
             assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).add(ONE).toString());
             assert.equal(pos0.uniPairHeld.toString(), pos.uniPairHeld.toString());
             assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

             const token0Bala = await posManager.tokenBalances(token0.address);
             const token1Bala = await posManager.tokenBalances(token1.address);

             const diff = BigNumber.from(pos.tokensHeld0.toString()).sub(BigNumber.from(pos0.tokensHeld0.toString()));

             const expToken0Bala = BigNumber.from(token0Bal.toString()).sub(diff);
             const expToken1Bala = BigNumber.from(token1Bal.toString()).add(ONE);

             assert.equal(token0Bala.toString(), expToken0Bala.toString());
             assert.equal(token1Bala.toString(), expToken1Bala.toString());
         });

        it('swapPositionTokensForExactTokens::buy', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(32), token1Amount.mul(32), accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));

             const res0 = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[1],
             deadline: constants.MaxUint256
             });

             await res0.wait();

             const pos = await posManager.positions(1);

             const token0Bal = await posManager.tokenBalances(token0.address);
             const token1Bal = await posManager.tokenBalances(token1.address);

             const ONE = expandTo18Decimals(1);

             const resp = await posManager
             .swapPositionTokensForExactTokens({ tokenId: 1, amount: ONE, side: true, slippage: constants.MaxUint256, deadline: constants.MaxUint256 });

             await resp.wait();

             const pos0 = await posManager.positions(1);

             assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).add(ONE).toString());
             assert.equal(BigNumber.from(pos0.tokensHeld1.toString()).lt(BigNumber.from(pos.tokensHeld1.toString())), true);
             assert.equal(pos0.uniPairHeld.toString(), pos.uniPairHeld.toString());
             assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

             const token0Bala = await posManager.tokenBalances(token0.address);
             const token1Bala = await posManager.tokenBalances(token1.address);

             const diff = BigNumber.from(pos.tokensHeld1.toString()).sub(BigNumber.from(pos0.tokensHeld1.toString()));

             const expToken1Bala = BigNumber.from(token1Bal.toString()).sub(diff);
             const expToken0Bala = BigNumber.from(token0Bal.toString()).add(ONE);

             assert.equal(token0Bala.toString(), expToken0Bala.toString());
             assert.equal(token1Bala.toString(), expToken1Bala.toString());

         });

         it('swapPositionTokensForExactTokens::failCollateral', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(8), token1Amount.mul(8), accounts[0]);

             //await token0.transfer(posManager.address, token0Amount.mul(1));
             //await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
                 token0: token0.address,
                 token1: token1.address,
                 liquidity: liquidity,
                 recipient: accounts[0],
                 deadline: constants.MaxUint256
             });

             await res.wait();

             const delta = expandTo18Decimals(75).div(100);
             const amount = liquidity.sub(delta);

             const resp2 = await posManager.decreaseCollateral(1, 0, 0, amount, accounts[0]);

             await resp2.wait();

             await pool.setSlope1(expandTo18Decimals(1000000));

             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));

             const ONE = expandTo18Decimals(1);

             await posManager
             .swapPositionTokensForExactTokens({ tokenId: 1, amount: ONE, side: false, slippage: constants.MaxUint256, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('VegaswapV1: INSUFFICIENT_COLLATERAL_DEPOSITED');
         });

         it('swapPositionTokensForExactTokens::failSlippage', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(2), token1Amount.mul(2), accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             const ONE = expandTo18Decimals(1);

             await posManager
             .swapPositionTokensForExactTokens({ tokenId: 1, amount: ONE, side: true, slippage: 0, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');

             await posManager
             .swapPositionTokensForExactTokens({ tokenId: 1, amount: ONE, side: false, slippage: 0, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('UniswapV2Router: EXCESSIVE_INPUT_AMOUNT');

         });

        it('swapPositionExactTokensForTokens::failCollateral', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(8), token1Amount.mul(8), accounts[0]);

             //await token0.transfer(posManager.address, token0Amount.mul(1));
             //await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
                 token0: token0.address,
                 token1: token1.address,
                 liquidity: liquidity,
                 recipient: accounts[0],
                 deadline: constants.MaxUint256
             });

             //await res.wait();

             const delta = expandTo18Decimals(75).div(100);
             const amount = liquidity.sub(delta);

             const resp2 = await posManager.decreaseCollateral(1, 0, 0, amount, accounts[0]);

             //await resp2.wait();

             await pool.setSlope1(expandTo18Decimals(1000000));

             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));
             await mineBlock(web3, Math.floor(Date.now()/1000));

             const ONE = expandTo18Decimals(1);

             await posManager
             .swapPositionExactTokensForTokens({ tokenId: 1, amount: ONE, side: false, slippage: constants.MaxUint256, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('VegaswapV1: INSUFFICIENT_COLLATERAL_DEPOSITED');
         });

         it('swapPositionExactTokensForTokens::sell', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount.mul(16), token1Amount.mul(16), accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));

             const res0 = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[1],
             deadline: constants.MaxUint256
             });

             await res0.wait();

             const pos = await posManager.positions(1);

             const token0Bal = await posManager.tokenBalances(token0.address);
             const token1Bal = await posManager.tokenBalances(token1.address);
             const ONE = expandTo18Decimals(1);

             const resp = await posManager
             .swapPositionExactTokensForTokens({ tokenId: 1, amount: ONE, side: false, slippage: constants.MaxUint256, deadline: constants.MaxUint256 });

             await resp.wait();

             const pos0 = await posManager.positions(1);

             assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(ONE));
             assert.equal(BigNumber.from(pos0.tokensHeld1.toString()).gt(BigNumber.from(pos.tokensHeld1.toString())), true);
             assert.equal(pos0.uniPairHeld.toString(), pos.uniPairHeld.toString());
             assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

             const token0Bala = await posManager.tokenBalances(token0.address);
             const token1Bala = await posManager.tokenBalances(token1.address);
             const expToken0Bala = BigNumber.from(token0Bal.toString()).sub(ONE);
             const expToken1Bala = BigNumber.from(token1Bal.toString()).add(BigNumber.from(pos0.tokensHeld1.toString()).sub(BigNumber.from(pos.tokensHeld1.toString())));
             assert.equal(token0Bala.toString(), expToken0Bala.toString());
             assert.equal(token1Bala.toString(), expToken1Bala.toString());
         });

         it('swapPositionExactTokensForTokens::buy', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);
             await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);
             await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));

             const res0 = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[1],
             deadline: constants.MaxUint256
             });

             await res0.wait();

             const pos = await posManager.positions(1);

             const token0Bal = await posManager.tokenBalances(token0.address);
             const token1Bal = await posManager.tokenBalances(token1.address);

             const ONE = expandTo18Decimals(1);

             const resp = await posManager
             .swapPositionExactTokensForTokens({ tokenId: 1, amount: ONE, side: true, slippage: constants.MaxUint256, deadline: constants.MaxUint256 });

             await resp.wait();

             const pos0 = await posManager.positions(1);

             assert.equal(BigNumber.from(pos0.tokensHeld0.toString()).gt(BigNumber.from(pos.tokensHeld0.toString())), true);
             assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(ONE));
             assert.equal(pos0.uniPairHeld.toString(), pos.uniPairHeld.toString());
             assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

             const token0Bala = await posManager.tokenBalances(token0.address);
             const token1Bala = await posManager.tokenBalances(token1.address);
             const expToken0Bala = BigNumber.from(token0Bal.toString()).add(BigNumber.from(pos0.tokensHeld0.toString()).sub(BigNumber.from(pos.tokensHeld0.toString())));
             const expToken1Bala = BigNumber.from(token1Bal.toString()).sub(ONE);

             assert.equal(token0Bala.toString(), expToken0Bala.toString());
             assert.equal(token1Bala.toString(), expToken1Bala.toString());

         });

         it('swapPositionExactTokensForTokens::failSlippage', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             const ONE = expandTo18Decimals(1);

             await posManager
             .swapPositionExactTokensForTokens({ tokenId: 1, amount: ONE, side: true, slippage: 0, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

             await posManager
             .swapPositionExactTokensForTokens({ tokenId: 1, amount: ONE, side: false, slippage: 0, deadline: constants.MaxUint256 })
             .should.be.rejectedWith('UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');

         });

         it('swapUniForTokensHeld::success', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             const token0Amount = expandTo18Decimals(1);
             const token1Amount = expandTo18Decimals(4);

             await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

             await token0.transfer(posManager.address, token0Amount.mul(1));
             await token1.transfer(posManager.address, token1Amount.mul(1));
             await uniPair.transfer(posManager.address, liquidity);

             const res = await posManager.mint({
             token0: token0.address,
             token1: token1.address,
             liquidity: liquidity,
             recipient: accounts[0],
             deadline: constants.MaxUint256
             });

             await res.wait();

             const pos = await posManager.positions(1);

             const token0Bal = await posManager.tokenBalances(token0.address);
             const token1Bal = await posManager.tokenBalances(token1.address);
             const uniPairBal = await posManager.tokenBalances(uniPair.address);
             const poolUniBal = await pool.totalUniLiquidity();

             await posManager.swapUniForTokensHeld(1, liquidity);

             const pos0 = await posManager.positions(1);

             const token0Bala = await posManager.tokenBalances(token0.address);
             const token1Bala = await posManager.tokenBalances(token1.address);
             const uniPairBala = await posManager.tokenBalances(uniPair.address);
             const poolUniBala = await pool.totalUniLiquidity();

             assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).add(token0Amount).toString());
             assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).add(token1Amount).toString());
             assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).sub(liquidity).toString());

             assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

             assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).add(token0Amount).toString());
             assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).add(token1Amount).toString());
             assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).sub(liquidity).toString());
             assert.equal(poolUniBala.toString(), poolUniBal.toString());
         });/**/










     /*it('swapUniForTokensHeld::failExcessiveLiquiditySwap', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount.mul(1));
     await token1.transfer(posManager.address, token1Amount.mul(1));
     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await posManager.swapUniForTokensHeld(1, liquidity.mul(2))
     .should.be.rejectedWith('VegaswapV1: EXCESSIVE_LIQUIDITY_SWAP');
     });

     it('swapTokensForUniHeld::failExcessiveAmount', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount.mul(1));
     await token1.transfer(posManager.address, token1Amount.mul(1));
     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await posManager.swapTokensForUniHeld(1, token0Amount.mul(3), token1Amount.mul(1), token0Amount, 0)
     .should.be.rejectedWith('VegaswapV1: EXCESSIVE_AMOUNT_SWAP');
     });

     it('swapTokensForUniHeld::imbalanced', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount.mul(3));
     await token1.transfer(posManager.address, token1Amount.mul(3));
     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     await posManager.swapTokensForUniHeld(1, token0Amount.mul(2), token1Amount.mul(1), token0Amount, 0);

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(token0Amount).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).add(liquidity).toString());

     assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(token0Amount).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).add(liquidity).toString());
     assert.equal(poolUniBala.toString(), poolUniBal.toString());

     await posManager.swapTokensForUniHeld(1, token0Amount.mul(1), token1Amount.mul(2), 0, token1Amount);

     const pos1 = await posManager.positions(1);

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);
     const poolUniBalb = await pool.totalUniLiquidity();

     assert.equal(pos1.tokensHeld0.toString(), BigNumber.from(pos0.tokensHeld0.toString()).sub(token0Amount).toString());
     assert.equal(pos1.tokensHeld1.toString(), BigNumber.from(pos0.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos1.uniPairHeld.toString(), BigNumber.from(pos0.uniPairHeld.toString()).add(liquidity).toString());

     assert.equal(pos1.liquidity.toString(), pos0.liquidity.toString());

     assert.equal(token0Balb.toString(), BigNumber.from(token0Bala.toString()).sub(token0Amount).toString());
     assert.equal(token1Balb.toString(), BigNumber.from(token1Bala.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBalb.toString(), BigNumber.from(uniPairBala.toString()).add(liquidity).toString());
     assert.equal(poolUniBalb.toString(), poolUniBala.toString());
     });

     it('swapTokensForUniHeld::balanced', async () => {

     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);
     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     await posManager.swapTokensForUniHeld(1, token0Amount, token1Amount, 0, 0);

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(token0Amount).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).add(liquidity).toString());

     assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(token0Amount).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).add(liquidity).toString());
     assert.equal(poolUniBala.toString(), poolUniBal.toString());
     });

     it('decreasePositionWithUniLiquidity::useOnlyUniTokens', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     assert.equal(pos.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.toString());
     assert.equal(pos.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     assert.equal(token0Bal.toString(), token0Amount.toString());
     assert.equal(token1Bal.toString(), token1Amount.toString());
     assert.equal(uniPairBal.toString(), liquidity.toString());
     assert.equal(poolUniBal.toString(), liquidity.toString());

     const tx = await posManager.swapTokensForUniHeld(1, token0Amount, token1Amount, 0, 0);
     await tx.wait();

     const pos0 = await posManager.positions(1);

     assert.equal(pos0.tokensHeld0.toString(), 0);
     assert.equal(pos0.tokensHeld1.toString(), 0);
     assert.equal(pos0.uniPairHeld.toString(), liquidity.mul(2).toString());
     assert.equal(pos0.liquidity.toString(), liquidity.toString());

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     assert.equal(token0Bala.toString(), 0);
     assert.equal(token1Bala.toString(), 0);
     assert.equal(uniPairBala.toString(), liquidity.mul(2).toString());
     assert.equal(poolUniBala.toString(), liquidity.toString());

     const resp = await posManager.decreasePositionWithUniLiquidity({
     tokenId: 1,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await resp.wait();

     const BORROWED_INVARIANT = await pool.BORROWED_INVARIANT();

     const pos1 = await posManager.positions(1);

     assert.equal(pos1.tokensHeld0.toString(), 0);
     assert.equal(pos1.tokensHeld1.toString(), 0);
     assert.equal(pos1.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos1.liquidity.toString(), BigNumber.from(BORROWED_INVARIANT.toString()).sub(2));

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);
     const poolUniBalb = await pool.totalUniLiquidity();

     assert.equal(token0Balb.toString(), 0);
     assert.equal(token1Balb.toString(), 0);
     assert.equal(uniPairBalb.toString(), pos1.uniPairHeld.toString());
     assert.equal(poolUniBalb.toString(), liquidity.mul(2).toString());
     });

     it('decreasePositionWithUniLiquidity::successExcessiveLiquidityBurned', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     assert.equal(pos.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.toString());
     assert.equal(pos.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     assert.equal(token0Bal.toString(), token0Amount.toString());
     assert.equal(token1Bal.toString(), token1Amount.toString());
     assert.equal(uniPairBal.toString(), liquidity.toString());
     assert.equal(poolUniBal.toString(), liquidity.toString());

     const tx = await posManager.swapTokensForUniHeld(1, token0Amount, token1Amount, 0, 0);
     await tx.wait();

     const pos0 = await posManager.positions(1);

     assert.equal(pos0.tokensHeld0.toString(), 0);
     assert.equal(pos0.tokensHeld1.toString(), 0);
     assert.equal(pos0.uniPairHeld.toString(), liquidity.mul(2).toString());
     assert.equal(pos0.liquidity.toString(), liquidity.toString());

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     assert.equal(token0Bala.toString(), 0);
     assert.equal(token1Bala.toString(), 0);
     assert.equal(uniPairBala.toString(), liquidity.mul(2).toString());
     assert.equal(poolUniBala.toString(), liquidity.toString());

     const resp = await posManager.decreasePositionWithUniLiquidity({
     tokenId: 1,
     liquidity: liquidity.mul(2),
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await resp.wait();

     const pos1 = await posManager.positions(1);

     const ONE = expandTo18Decimals(1);

     const diff = ONE.mul(2).sub(BigNumber.from(pos1.uniPairHeld.toString()));

     assert.equal(pos1.tokensHeld0.toString(), 0);
     assert.equal(pos1.tokensHeld1.toString(), 0);
     assert.equal(pos1.uniPairHeld.toString(), liquidity.sub(diff).toString());
     assert.equal(pos1.liquidity.toString(), 0);

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);
     const poolUniBalb = await pool.totalUniLiquidity();

     assert.equal(token0Balb.toString(), 0);
     assert.equal(token1Balb.toString(), 0);
     assert.equal(uniPairBalb.toString(), pos1.uniPairHeld.toString());
     assert.equal(poolUniBalb.toString(), liquidity.mul(2).add(diff).toString());
     });

     it('decreasePositionWithUniLiquidity::useTokens', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     await posManager.decreasePositionWithUniLiquidity({
     tokenId: 1,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     const ONE = expandTo18Decimals(1);

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(0).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(0).toString());
     assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).sub(liquidity).toString());

     assert.equal(BigNumber.from(pos0.liquidity.toString()).lt(BigNumber.from(pos.liquidity.toString()).sub(liquidity).add(ONE.div(10)).toString()), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(0).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(0).toString());
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).sub(liquidity).toString());
     assert.equal(poolUniBala.toString(), BigNumber.from(poolUniBal.toString()).add(liquidity).toString());
     });

     it('decreasePositionWithUniLiquidity::failNotEnoughLiquidityProvided', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await posManager.decreasePositionWithUniLiquidity({
     tokenId: 1,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     }).should.be.rejectedWith('VegaswapV1: NOT_ENOUGH_LIQUIDITY_PROVIDED');
     });

     it('decreasePositionWithUniLiquidity::failIsUnderwater', async () => {
     await pool.setSlope1(expandTo18Decimals(1000000));

     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await uniPair.transfer(posManager.address, liquidity);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await mineBlock(web3, Math.floor(Date.now()/1000));
     await mineBlock(web3, Math.floor(Date.now()/1000));
     await mineBlock(web3, Math.floor(Date.now()/1000));
     await mineBlock(web3, Math.floor(Date.now()/1000));
     await mineBlock(web3, Math.floor(Date.now()/1000));

     await posManager.decreasePositionWithUniLiquidity({
     tokenId: 1,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     }).should.be.rejectedWith('VegaswapV1: IS_UNDERWATER');
     });/**/

     /*it('decreasePosition::failIsUnderwater', async () => {
     await pool.setSlope1(expandTo18Decimals(100000000));

     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await openPosition(token0Amount, token1Amount, liquidity, accounts[0]);

         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));

         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
         await mineBlock(web3, Math.floor(Date.now()/1000));
     await posManager.decreasePosition(1,liquidity).should.be.rejectedWith('PositionManager: IS_UNDERWATER');
     });/**/

     /*it('decreasePosition::excessiveLiquidityBurned', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     assert.notEqual(pos.liquidity.toString(), 0);
     assert.notEqual(pos.tokensHeld0.toString(), token0Amount.toString());
     assert.notEqual(pos.tokensHeld1.toString(), token1Amount.toString());
     assert.equal(pos.uniPairHeld.toString(), 0);

     await pool.getAndUpdateLastFeeIndex();

     const UNI_LP_BORROWED = await pool.UNI_LP_BORROWED();
     assert.equal(UNI_LP_BORROWED.toString(), liquidity);

     await posManager.decreasePosition({
     tokenId: 1,
     liquidity: liquidity.mul(2),
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const pos0 = await posManager.positions(1);

     const UNI_LP_BORROWEDa = await pool.UNI_LP_BORROWED();

     assert.equal(pos0.liquidity.toString(), 0);
     assert.equal(BigNumber.from(pos0.tokensHeld0.toString()).lt(BigNumber.from(pos.tokensHeld0.toString()).sub(token0Amount)), true);
     assert.equal(BigNumber.from(pos0.tokensHeld1.toString()).lt(BigNumber.from(pos.tokensHeld1.toString()).sub(token1Amount)), true);
     assert.equal(pos0.uniPairHeld.toString(), 0);
     assert.equal(UNI_LP_BORROWEDa.toString(), 0);

     });

     it('decreasePosition::tokenDeposit', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await token0.transfer(posManager.address, token0Amount.mul(2));
     await token1.transfer(posManager.address, token1Amount.mul(2));

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity.mul(2),
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     await posManager.decreasePosition({
     tokenId: 1,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     const ONE = expandTo18Decimals(1);

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(0).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(0).toString());
     assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).sub(0).toString());
     assert.equal(BigNumber.from(pos0.liquidity.toString()).lt(BigNumber.from(pos.liquidity.toString()).sub(liquidity).add(ONE.div(10)).toString()), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(0).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(0).toString());
     assert.equal(uniPairBala.toString(), uniPairBal.toString());
     assert.equal(poolUniBala.toString(), BigNumber.from(poolUniBal.toString()).add(liquidity).toString());
     });

     it('decreasePosition::noTokenDeposit', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await token0.transfer(posManager.address, token0Amount.mul(2));
     await token1.transfer(posManager.address, token1Amount.mul(2));

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity.mul(2),
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);
     const poolUniBal = await pool.totalUniLiquidity();

     await posManager.decreasePosition({ tokenId: 1, liquidity: liquidity, recipient: accounts[0], deadline: constants.MaxUint256 });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);
     const poolUniBala = await pool.totalUniLiquidity();

     const ONE = expandTo18Decimals(1);

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(token0Amount).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos0.uniPairHeld.toString(), BigNumber.from(pos.uniPairHeld.toString()).sub(0).toString());
     assert.equal(BigNumber.from(pos0.liquidity.toString()).lt(BigNumber.from(pos.liquidity.toString()).sub(liquidity).add(ONE.div(10)).toString()), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(token0Amount).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBala.toString(), uniPairBal.toString());
     assert.equal(poolUniBala.toString(), BigNumber.from(poolUniBal.toString()).add(liquidity).toString());
     });

     it('decreaseCollateral::failDecrease', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await posManager.decreaseCollateral(1, token0Amount, token1Amount, 0, accounts[0]).should.be.rejectedWith('VegaswapV1: EXCESSIVE_COLLATERAL_REMOVAL');
     });

     it('decreaseCollateral', async () => {
     await setUp();
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount.mul(5), token1Amount.mul(5), accounts[0]);

     await token0.transfer(posManager.address, token0Amount.mul(5));
     await token1.transfer(posManager.address, token1Amount.mul(5));
     await uniPair.transfer(posManager.address, liquidity.mul(5));

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     const userToken0Bal = await token0.balanceOf(accounts[0]);
     const userToken1Bal = await token1.balanceOf(accounts[0]);
     const userUniPairBal = await uniPair.balanceOf(accounts[0]);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);

     await posManager.decreaseCollateral(1, token0Amount, token1Amount, 0, accounts[0]);

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);

     const userToken0Bala = await token0.balanceOf(accounts[0]);
     const userToken1Bala = await token1.balanceOf(accounts[0]);
     const userUniPairBala = await uniPair.balanceOf(accounts[0]);

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).sub(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos0.uniPairHeld.toString(), liquidity.mul(5).toString());//liquidity.toString());
     assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).sub(token0Amount).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBala.toString(), uniPairBal.toString());//.add(liquidity));

     assert.equal(userToken0Bala.toString(), BigNumber.from(userToken0Bal.toString()).add(token0Amount).toString());
     assert.equal(userToken1Bala.toString(), BigNumber.from(userToken1Bal.toString()).add(token1Amount).toString());
     assert.equal(userUniPairBala.toString(), BigNumber.from(userUniPairBal.toString()).add(0).toString());

     await posManager.decreaseCollateral(1, token0Amount, token1Amount, liquidity, accounts[0]);

     const pos1 = await posManager.positions(1);

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);

     const userToken0Balb = await token0.balanceOf(accounts[0]);
     const userToken1Balb = await token1.balanceOf(accounts[0]);
     const userUniPairBalb = await uniPair.balanceOf(accounts[0]);

     assert.equal(pos1.tokensHeld0.toString(), BigNumber.from(pos0.tokensHeld0.toString()).sub(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos1.tokensHeld1.toString(), BigNumber.from(pos0.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos1.uniPairHeld.toString(), liquidity.mul(4).toString());//liquidity.toString());
     assert.equal(pos1.liquidity.toString(), pos0.liquidity.toString());

     assert.equal(token0Balb.toString(), BigNumber.from(token0Bala.toString()).sub(token0Amount).toString());
     assert.equal(token1Balb.toString(), BigNumber.from(token1Bala.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBalb.toString(), BigNumber.from(uniPairBala.toString()).sub(liquidity).toString());

     assert.equal(userToken0Balb.toString(), BigNumber.from(userToken0Bala.toString()).add(token0Amount).toString());
     assert.equal(userToken1Balb.toString(), BigNumber.from(userToken1Bala.toString()).add(token1Amount).toString());
     assert.equal(userUniPairBalb.toString(), BigNumber.from(userUniPairBala.toString()).add(liquidity).toString());

     await posManager.decreaseCollateral(1, 0, 0, liquidity, accounts[0]);

     const pos2 = await posManager.positions(1);

     const token0Balc = await posManager.tokenBalances(token0.address);
     const token1Balc = await posManager.tokenBalances(token1.address);
     const uniPairBalc = await posManager.tokenBalances(uniPair.address);

     const userToken0Balc = await token0.balanceOf(accounts[0]);
     const userToken1Balc = await token1.balanceOf(accounts[0]);
     const userUniPairBalc = await uniPair.balanceOf(accounts[0]);

     assert.equal(pos2.tokensHeld0.toString(), BigNumber.from(pos1.tokensHeld0.toString()).sub(0).toString());//.mul(4).toString());
     assert.equal(pos2.tokensHeld1.toString(), BigNumber.from(pos1.tokensHeld1.toString()).sub(0).toString());
     assert.equal(pos2.uniPairHeld.toString(), liquidity.mul(3).toString());//liquidity.toString());
     assert.equal(pos2.liquidity.toString(), pos1.liquidity.toString());

     assert.equal(token0Balc.toString(), BigNumber.from(token0Balb.toString()).sub(0).toString());
     assert.equal(token1Balc.toString(), BigNumber.from(token1Balb.toString()).sub(0).toString());
     assert.equal(uniPairBalc.toString(), BigNumber.from(uniPairBalb.toString()).sub(liquidity).toString());

     assert.equal(userToken0Balc.toString(), BigNumber.from(userToken0Balb.toString()).add(0).toString());
     assert.equal(userToken1Balc.toString(), BigNumber.from(userToken1Balb.toString()).add(0).toString());
     assert.equal(userUniPairBalc.toString(), BigNumber.from(userUniPairBalb.toString()).add(liquidity).toString());

     await posManager.decreaseCollateral(1, token0Amount, 0, 0, accounts[0]);

     const pos3 = await posManager.positions(1);

     const token0Bald = await posManager.tokenBalances(token0.address);
     const token1Bald = await posManager.tokenBalances(token1.address);
     const uniPairBald = await posManager.tokenBalances(uniPair.address);

     const userToken0Bald = await token0.balanceOf(accounts[0]);
     const userToken1Bald = await token1.balanceOf(accounts[0]);
     const userUniPairBald = await uniPair.balanceOf(accounts[0]);

     assert.equal(pos3.tokensHeld0.toString(), BigNumber.from(pos2.tokensHeld0.toString()).sub(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos3.tokensHeld1.toString(), BigNumber.from(pos2.tokensHeld1.toString()).sub(0).toString());
     assert.equal(pos3.uniPairHeld.toString(), liquidity.mul(3).toString());//liquidity.toString());
     assert.equal(pos3.liquidity.toString(), pos2.liquidity.toString());

     assert.equal(token0Bald.toString(), BigNumber.from(token0Balc.toString()).sub(token0Amount).toString());
     assert.equal(token1Bald.toString(), BigNumber.from(token1Balc.toString()).sub(0).toString());
     assert.equal(uniPairBald.toString(), BigNumber.from(uniPairBalc.toString()).sub(0).toString());

     assert.equal(userToken0Bald.toString(), BigNumber.from(userToken0Balc.toString()).add(token0Amount).toString());
     assert.equal(userToken1Bald.toString(), BigNumber.from(userToken1Balc.toString()).add(0).toString());
     assert.equal(userUniPairBald.toString(), BigNumber.from(userUniPairBalc.toString()).add(0).toString());

     await posManager.decreaseCollateral(1, 0, token1Amount, 0, accounts[0]);

     const pos4 = await posManager.positions(1);

     const token0Bale = await posManager.tokenBalances(token0.address);
     const token1Bale = await posManager.tokenBalances(token1.address);
     const uniPairBale = await posManager.tokenBalances(uniPair.address);

     const userToken0Bale = await token0.balanceOf(accounts[0]);
     const userToken1Bale = await token1.balanceOf(accounts[0]);
     const userUniPairBale = await uniPair.balanceOf(accounts[0]);

     assert.equal(pos4.tokensHeld0.toString(), BigNumber.from(pos3.tokensHeld0.toString()).sub(0).toString());//.mul(4).toString());
     assert.equal(pos4.tokensHeld1.toString(), BigNumber.from(pos3.tokensHeld1.toString()).sub(token1Amount).toString());
     assert.equal(pos4.uniPairHeld.toString(), liquidity.mul(3).toString());//liquidity.toString());
     assert.equal(pos4.liquidity.toString(), pos3.liquidity.toString());

     assert.equal(token0Bale.toString(), BigNumber.from(token0Bald.toString()).sub(0).toString());
     assert.equal(token1Bale.toString(), BigNumber.from(token1Bald.toString()).sub(token1Amount).toString());
     assert.equal(uniPairBale.toString(), BigNumber.from(uniPairBald.toString()).sub(0).toString());

     assert.equal(userToken0Bale.toString(), BigNumber.from(userToken0Bald.toString()).add(0).toString());
     assert.equal(userToken1Bale.toString(), BigNumber.from(userToken1Bald.toString()).add(token1Amount).toString());
     assert.equal(userUniPairBale.toString(), BigNumber.from(userUniPairBald.toString()).add(0).toString());
     });

     it('increaseCollateral', async () => {
     await setUp();
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);
     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     const pos = await posManager.positions(1);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);

     await posManager.increaseCollateral(1);

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos0.tokensHeld0.toString(), BigNumber.from(pos.tokensHeld0.toString()).add(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos0.tokensHeld1.toString(), BigNumber.from(pos.tokensHeld1.toString()).add(token1Amount).toString());
     assert.equal(pos0.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(pos0.liquidity.toString(), pos.liquidity.toString());

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).add(token0Amount).toString());
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).add(token1Amount).toString());
     assert.equal(uniPairBala.toString(), uniPairBal.toString());//.add(liquidity));

     await token0.transfer(posManager.address, token0Amount);
     await posManager.increaseCollateral(1);

     const pos1 = await posManager.positions(1);

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos1.tokensHeld0.toString(), BigNumber.from(pos0.tokensHeld0.toString()).add(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos1.tokensHeld1.toString(), BigNumber.from(pos0.tokensHeld1.toString()).add(0).toString());
     assert.equal(pos1.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(pos1.liquidity.toString(), pos0.liquidity.toString());

     assert.equal(token0Balb.toString(), BigNumber.from(token0Bala.toString()).add(token0Amount).toString());
     assert.equal(token1Balb.toString(), BigNumber.from(token1Bala.toString()).add(0).toString());
     assert.equal(uniPairBalb.toString(), uniPairBala.toString());

     await token1.transfer(posManager.address, token1Amount);

     await posManager.increaseCollateral(1);

     const pos2 = await posManager.positions(1);

     const token0Balc = await posManager.tokenBalances(token0.address);
     const token1Balc = await posManager.tokenBalances(token1.address);
     const uniPairBalc = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos2.tokensHeld0.toString(), BigNumber.from(pos1.tokensHeld0.toString()).add(0).toString());//.mul(4).toString());
     assert.equal(pos2.tokensHeld1.toString(), BigNumber.from(pos1.tokensHeld1.toString()).add(token1Amount).toString());
     assert.equal(pos2.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(pos2.liquidity.toString(), pos1.liquidity.toString());

     assert.equal(token0Balc.toString(), BigNumber.from(token0Balb.toString()).add(0).toString());
     assert.equal(token1Balc.toString(), BigNumber.from(token1Balb.toString()).add(token1Amount).toString());
     assert.equal(uniPairBalc.toString(), uniPairBalb.toString());//.add(liquidity));

     await uniPair.transfer(posManager.address, liquidity);

     await posManager.increaseCollateral(1);

     const pos3 = await posManager.positions(1);

     const token0Bald = await posManager.tokenBalances(token0.address);
     const token1Bald = await posManager.tokenBalances(token1.address);
     const uniPairBald = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos3.tokensHeld0.toString(), BigNumber.from(pos2.tokensHeld0.toString()).add(0).toString());//.mul(4).toString());
     assert.equal(pos3.tokensHeld1.toString(), BigNumber.from(pos2.tokensHeld1.toString()).add(0).toString());
     assert.equal(pos3.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos3.liquidity.toString(), pos2.liquidity.toString());

     assert.equal(token0Bald.toString(), BigNumber.from(token0Balc.toString()).add(0).toString());
     assert.equal(token1Bald.toString(), BigNumber.from(token1Balc.toString()).add(0).toString());
     assert.equal(uniPairBald.toString(), BigNumber.from(uniPairBalc.toString()).add(liquidity).toString());

     await uniPair.transfer(posManager.address, liquidity);
     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     await posManager.increaseCollateral(1);

     const pos4 = await posManager.positions(1);

     const token0Bale = await posManager.tokenBalances(token0.address);
     const token1Bale = await posManager.tokenBalances(token1.address);
     const uniPairBale = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos4.tokensHeld0.toString(), BigNumber.from(pos3.tokensHeld0.toString()).add(token0Amount).toString());//.mul(4).toString());
     assert.equal(pos4.tokensHeld1.toString(), BigNumber.from(pos3.tokensHeld1.toString()).add(token1Amount).toString());
     assert.equal(pos4.uniPairHeld.toString(), liquidity.mul(2).toString());
     assert.equal(pos4.liquidity.toString(), pos3.liquidity.toString());

     assert.equal(token0Bale.toString(), BigNumber.from(token0Bald.toString()).add(token0Amount).toString());
     assert.equal(token1Bale.toString(), BigNumber.from(token1Bald.toString()).add(token1Amount).toString());
     assert.equal(uniPairBale.toString(), BigNumber.from(uniPairBald.toString()).add(liquidity).toString());
     });

     it('increasePosition::increaseByTokens', async () => {
     await setUp();
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos0.tokensHeld0.toString(), token0Amount.mul(4).toString());
     assert.equal(pos0.tokensHeld1.toString(), token1Amount.mul(4).toString());
     assert.equal(pos0.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(BigNumber.from(pos0.liquidity.toString()).gt(liquidity.mul(2)), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).add(token0Amount.mul(2)));
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).add(token1Amount.mul(2)));
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()));//.add(liquidity));

     await token0.transfer(posManager.address, token0Amount);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     });

     const pos1 = await posManager.positions(1);

     const token0Balb = await posManager.tokenBalances(token0.address);
     const token1Balb = await posManager.tokenBalances(token1.address);
     const uniPairBalb = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos1.tokensHeld0.toString(), token0Amount.mul(6).toString());
     assert.equal(pos1.tokensHeld1.toString(), token1Amount.mul(5).toString());
     assert.equal(pos1.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(BigNumber.from(pos1.liquidity.toString()).gt(liquidity.mul(3)), true);

     assert.equal(token0Balb.toString(), BigNumber.from(token0Bala.toString()).add(token0Amount.mul(2)));
     assert.equal(token1Balb.toString(), BigNumber.from(token1Bala.toString()).add(token1Amount.mul(1)));
     assert.equal(uniPairBalb.toString(), BigNumber.from(uniPairBala.toString()));//.add(liquidity));

     await token1.transfer(posManager.address, token1Amount);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     });

     const pos2 = await posManager.positions(1);

     const token0Balc = await posManager.tokenBalances(token0.address);
     const token1Balc = await posManager.tokenBalances(token1.address);
     const uniPairBalc = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos2.tokensHeld0.toString(), token0Amount.mul(7).toString());
     assert.equal(pos2.tokensHeld1.toString(), token1Amount.mul(7).toString());
     assert.equal(pos2.uniPairHeld.toString(), 0);//liquidity.toString());
     assert.equal(BigNumber.from(pos2.liquidity.toString()).gt(liquidity.mul(4)), true);

     assert.equal(token0Balc.toString(), BigNumber.from(token0Balb.toString()).add(token0Amount.mul(1)));
     assert.equal(token1Balc.toString(), BigNumber.from(token1Balb.toString()).add(token1Amount.mul(2)));
     assert.equal(uniPairBalc.toString(), BigNumber.from(uniPairBalb.toString()));//.add(liquidity));
     });

     it('increasePosition::increaseByUniPair', async () => {
     await setUp();
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await uniPair.transfer(posManager.address, liquidity);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos0.tokensHeld0.toString(), token0Amount.mul(3).toString());
     assert.equal(pos0.tokensHeld1.toString(), token1Amount.mul(3).toString());
     assert.equal(pos0.uniPairHeld.toString(), liquidity.toString());
     assert.equal(BigNumber.from(pos0.liquidity.toString()).gt(liquidity.mul(2)), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).add(token0Amount.mul(1)));
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).add(token1Amount.mul(1)));
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).add(liquidity));
     });

     it('increasePosition::increaseByTokensAndUniPair', async () => {
     await setUp();
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await token0.transfer(posManager.address, token0Amount);
     await token1.transfer(posManager.address, token1Amount);
     await uniPair.transfer(posManager.address, liquidity);

     const token0Bal = await posManager.tokenBalances(token0.address);
     const token1Bal = await posManager.tokenBalances(token1.address);
     const uniPairBal = await posManager.tokenBalances(uniPair.address);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     });

     const pos0 = await posManager.positions(1);

     const token0Bala = await posManager.tokenBalances(token0.address);
     const token1Bala = await posManager.tokenBalances(token1.address);
     const uniPairBala = await posManager.tokenBalances(uniPair.address);

     assert.equal(pos0.tokensHeld0.toString(), token0Amount.mul(4).toString());
     assert.equal(pos0.tokensHeld1.toString(), token1Amount.mul(4).toString());
     assert.equal(pos0.uniPairHeld.toString(), liquidity.toString());
     assert.equal(BigNumber.from(pos0.liquidity.toString()).gt(liquidity.mul(2)), true);

     assert.equal(token0Bala.toString(), BigNumber.from(token0Bal.toString()).add(token0Amount.mul(2)));
     assert.equal(token1Bala.toString(), BigNumber.from(token1Bal.toString()).add(token1Amount.mul(2)));
     assert.equal(uniPairBala.toString(), BigNumber.from(uniPairBal.toString()).add(liquidity));
     });

     it('increasePosition::failUnderCollateralized', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     token0.transfer(posManager.address, token0Amount);
     token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     await res.wait();

     await addLiquidity(token0Amount, token1Amount, accounts[1]);
     await addLiquidity(token0Amount, token1Amount, accounts[0]);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity.mul(2),
     deadline: constants.MaxUint256,
     }).should.be.rejectedWith('VegaswapV1: INSUFFICIENT_COLLATERAL_DEPOSITED');

     });

     it('increasePosition::failNotAuthorized', async () => {
     await setUp();

     let liquidity = expandTo18Decimals(2);

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     token0.transfer(posManager.address, token0Amount);
     token1.transfer(posManager.address, token1Amount);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[1],
     deadline: constants.MaxUint256
     });

     await res.wait();

     token0.transfer(posManager.address, token0Amount);
     token1.transfer(posManager.address, token1Amount);

     await posManager.increasePosition({
     tokenId: 1,
     liquidity: liquidity,
     deadline: constants.MaxUint256,
     }).should.be.rejectedWith('VegaswapV1: NOT_AUTHORIZED');

     });/**/

     /*it('mint::failUnderCollateralized', async () => {
         await setUp();

         let liquidity = expandTo18Decimals(2);
         //const res =
             await posManager.openPosition(token0.address, token1.address, constants.Zero, constants.Zero, liquidity, accounts[0]).should.be.rejectedWith('GammaswapPosLibrary:: INSUFFICIENT_COLLATERAL_DEPOSITED');
         console.log("res >> ");
         //console.log(res);
     });/**/

     /*it('mint::depositUniTokenOnly', async () => {
     await setUp();

     const _posManToken0Bal = await token0.balanceOf(posManager.address);
     const _posManToken1Bal = await token1.balanceOf(posManager.address);
     const _posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const _posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const _posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const _posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.equal(_posManToken0Bal.toString(), _posManTokenBalance0.toString());
     assert.equal(_posManToken1Bal.toString(), _posManTokenBalance1.toString());
     assert.equal(_posManUniPairBal.toString(), _posManUniPairBalance.toString());

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     let liquidity = expandTo18Decimals(2);
     uniPair.transfer(posManager.address, liquidity);

     const posManToken0Bal = await token0.balanceOf(posManager.address);
     const posManToken1Bal = await token1.balanceOf(posManager.address);
     const posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.equal(posManToken0Bal.toString(), posManTokenBalance0.toString());
     assert.equal(posManToken1Bal.toString(), posManTokenBalance1.toString());
     assert.notEqual(posManUniPairBal.toString(), posManUniPairBalance.toString());

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const tx = await res.wait();

     const posManToken0Balb = await token0.balanceOf(posManager.address);
     const posManToken1Balb = await token1.balanceOf(posManager.address);
     const posManUniPairBalb = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0b = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1b = await posManager.tokenBalances(token1.address);
     const posManUniPairBalanceb = await posManager.tokenBalances(uniPair.address);

     assert.equal(posManToken0Balb.toString(), posManTokenBalance0b.toString());
     assert.equal(posManToken1Balb.toString(), posManTokenBalance1b.toString());
     assert.equal(posManUniPairBalb.toString(), posManUniPairBalanceb.toString());

     const event = tx.events[tx.logs.length - 1];

     assert.equal(event.args.liquidity.toString(), liquidity.toString());
     assert.equal(event.args.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(event.args.tokensHeld1.toString(), token1Amount.toString());
     assert.equal(event.args.uniPairHeld.toString(), liquidity.toString());

     const lfi = await pool.getLastFeeIndex();

     assert.equal(event.args.accFeeIndex.toString(), lfi._accFeeIndex.toString());

     const tokenId = BigNumber.from(event.args.tokenId.toString());

     const poolId = await factory.getPool(token0.address, token1.address);

     assert.equal(poolId.toString(), pool.address);

     const pos = await posManager.positions(tokenId);

     const blockNum = await web3.eth.getBlockNumber();

     assert.equal(pos.poolId.toString(), pool.address);
     assert.equal(pos.token0.toString(), token0.address);
     assert.equal(pos.token1.toString(), token1.address);
     assert.equal(pos.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.toString());
     assert.equal(pos.uniPair.toString(), uniPair.address);
     assert.equal(pos.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos.blockNum.toString(), blockNum.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());
     assert.equal(pos.rateIndex.toString(), lfi._accFeeIndex.toString());
     });

     it('mint::deposit1Token', async () => {
     await setUp();

     const _posManToken0Bal = await token0.balanceOf(posManager.address);
     const _posManToken1Bal = await token1.balanceOf(posManager.address);
     const _posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const _posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const _posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const _posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.equal(_posManToken0Bal.toString(), _posManTokenBalance0.toString());
     assert.equal(_posManToken1Bal.toString(), _posManTokenBalance1.toString());
     assert.equal(_posManUniPairBal.toString(), _posManUniPairBalance.toString());

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     let liquidity = expandTo18Decimals(2);

     token1.transfer(posManager.address, token1Amount.mul(2));

     const posManToken0Bal = await token0.balanceOf(posManager.address);
     const posManToken1Bal = await token1.balanceOf(posManager.address);
     const posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.equal(posManToken0Bal.toString(), posManTokenBalance0.toString());
     assert.notEqual(posManToken1Bal.toString(), posManTokenBalance1.toString());
     assert.equal(posManUniPairBal.toString(), posManUniPairBalance.toString());

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const tx = await res.wait();

     const posManToken0Balb = await token0.balanceOf(posManager.address);
     const posManToken1Balb = await token1.balanceOf(posManager.address);
     const posManUniPairBalb = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0b = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1b = await posManager.tokenBalances(token1.address);
     const posManUniPairBalanceb = await posManager.tokenBalances(uniPair.address);

     assert.equal(posManToken0Balb.toString(), posManTokenBalance0b.toString());
     assert.equal(posManToken1Balb.toString(), posManTokenBalance1b.toString());
     assert.equal(posManUniPairBalb.toString(), posManUniPairBalanceb.toString());

     const event = tx.events[tx.logs.length - 1];

     assert.equal(event.args.liquidity.toString(), liquidity.toString());
     assert.equal(event.args.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(event.args.tokensHeld1.toString(), token1Amount.mul(3).toString());
     assert.equal(event.args.uniPairHeld.toString(), 0);

     const lfi = await pool.getLastFeeIndex();

     assert.equal(event.args.accFeeIndex.toString(), lfi._accFeeIndex.toString());

     const tokenId = BigNumber.from(event.args.tokenId.toString());

     const poolId = await factory.getPool(token0.address, token1.address);

     assert.equal(poolId.toString(), pool.address);

     const pos = await posManager.positions(tokenId);

     const blockNum = await web3.eth.getBlockNumber();

     assert.equal(pos.poolId.toString(), pool.address);
     assert.equal(pos.token0.toString(), token0.address);
     assert.equal(pos.token1.toString(), token1.address);
     assert.equal(pos.tokensHeld0.toString(), token0Amount.toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.mul(3).toString());
     assert.equal(pos.uniPair.toString(), uniPair.address);
     assert.equal(pos.uniPairHeld.toString(), 0);
     assert.equal(pos.blockNum.toString(), blockNum.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());
     assert.equal(pos.rateIndex.toString(), lfi._accFeeIndex.toString());
     });

     it('mint::deposit2TokensPlusUni', async () => {
     await setUp();

     const _posManToken0Bal = await token0.balanceOf(posManager.address);
     const _posManToken1Bal = await token1.balanceOf(posManager.address);
     const _posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const _posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const _posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const _posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.equal(_posManToken0Bal.toString(), _posManTokenBalance0.toString());
     assert.equal(_posManToken1Bal.toString(), _posManTokenBalance1.toString());
     assert.equal(_posManUniPairBal.toString(), _posManUniPairBalance.toString());

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);

     await addToUniLiquidity(token0Amount, token1Amount, accounts[0]);

     let liquidity = expandTo18Decimals(2);

     token0.transfer(posManager.address, token0Amount);
     token1.transfer(posManager.address, token1Amount);
     uniPair.transfer(posManager.address, liquidity);

     const posManToken0Bal = await token0.balanceOf(posManager.address);
     const posManToken1Bal = await token1.balanceOf(posManager.address);
     const posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const posManUniPairBalance = await posManager.tokenBalances(uniPair.address);

     assert.notEqual(posManToken0Bal.toString(), posManTokenBalance0.toString());
     assert.notEqual(posManToken1Bal.toString(), posManTokenBalance1.toString());
     assert.notEqual(posManUniPairBal.toString(), posManUniPairBalance.toString());

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const tx = await res.wait();

     const posManToken0Balb = await token0.balanceOf(posManager.address);
     const posManToken1Balb = await token1.balanceOf(posManager.address);
     const posManUniPairBalb = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0b = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1b = await posManager.tokenBalances(token1.address);
     const posManUniPairBalanceb = await posManager.tokenBalances(uniPair.address);

     assert.equal(posManToken0Balb.toString(), posManTokenBalance0b.toString());
     assert.equal(posManToken1Balb.toString(), posManTokenBalance1b.toString());
     assert.equal(posManUniPairBalb.toString(), posManUniPairBalanceb.toString());

     const event = tx.events[tx.logs.length - 1];

     assert.equal(event.args.liquidity.toString(), liquidity.toString());
     assert.equal(event.args.tokensHeld0.toString(), token0Amount.mul(2).toString());
     assert.equal(event.args.tokensHeld1.toString(), token1Amount.mul(2).toString());
     assert.equal(event.args.uniPairHeld.toString(), liquidity.toString());

     const lfi = await pool.getLastFeeIndex();

     assert.equal(event.args.accFeeIndex.toString(), lfi._accFeeIndex.toString());

     const tokenId = BigNumber.from(event.args.tokenId.toString());

     const poolId = await factory.getPool(token0.address, token1.address);

     assert.equal(poolId.toString(), pool.address);

     const pos = await posManager.positions(tokenId);

     const blockNum = await web3.eth.getBlockNumber();

     assert.equal(pos.poolId.toString(), pool.address);
     assert.equal(pos.token0.toString(), token0.address);
     assert.equal(pos.token1.toString(), token1.address);
     assert.equal(pos.tokensHeld0.toString(), token0Amount.mul(2).toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.mul(2).toString());
     assert.equal(pos.uniPair.toString(), uniPair.address);
     assert.equal(pos.uniPairHeld.toString(), liquidity.toString());
     assert.equal(pos.blockNum.toString(), blockNum.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());
     assert.equal(pos.rateIndex.toString(), lfi._accFeeIndex.toString());
     });

     it('mint::deposit2Tokens', async () => {
     await setUp();

     const _posManToken0Bal = await token0.balanceOf(posManager.address);
     const _posManToken1Bal = await token1.balanceOf(posManager.address);
     const _posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const _posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const _posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const _posManUniPairBalance = await uniPair.balanceOf(posManager.address);

     assert.equal(_posManToken0Bal.toString(), _posManTokenBalance0.toString());
     assert.equal(_posManToken1Bal.toString(), _posManTokenBalance1.toString());
     assert.equal(_posManUniPairBal.toString(), _posManUniPairBalance.toString());

     const token0Amount = expandTo18Decimals(1);
     const token1Amount = expandTo18Decimals(4);
     token0.transfer(posManager.address, token0Amount);
     token1.transfer(posManager.address, token1Amount);

     const posManToken0Bal = await token0.balanceOf(posManager.address);
     const posManToken1Bal = await token1.balanceOf(posManager.address);
     const posManUniPairBal = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0 = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1 = await posManager.tokenBalances(token1.address);
     const posManUniPairBalance = await uniPair.balanceOf(posManager.address);

     assert.notEqual(posManToken0Bal.toString(), posManTokenBalance0.toString());
     assert.notEqual(posManToken1Bal.toString(), posManTokenBalance1.toString());
     assert.equal(posManUniPairBal.toString(), posManUniPairBalance.toString());

     let liquidity = expandTo18Decimals(2);

     const res = await posManager.mint({
     token0: token0.address,
     token1: token1.address,
     liquidity: liquidity,
     recipient: accounts[0],
     deadline: constants.MaxUint256
     });

     const tx = await res.wait();

     const posManToken0Balb = await token0.balanceOf(posManager.address);
     const posManToken1Balb = await token1.balanceOf(posManager.address);
     const posManUniPairBalb = await uniPair.balanceOf(posManager.address);

     const posManTokenBalance0b = await posManager.tokenBalances(token0.address);
     const posManTokenBalance1b = await posManager.tokenBalances(token1.address);
     const posManUniPairBalanceb = await uniPair.balanceOf(posManager.address);

     assert.equal(posManToken0Balb.toString(), posManTokenBalance0b.toString());
     assert.equal(posManToken1Balb.toString(), posManTokenBalance1b.toString());
     assert.equal(posManUniPairBalb.toString(), posManUniPairBalanceb.toString());

     const event = tx.events[tx.logs.length - 1];

     assert.equal(event.args.liquidity.toString(), liquidity.toString());
     assert.equal(event.args.tokensHeld0.toString(), token0Amount.mul(2).toString());
     assert.equal(event.args.tokensHeld1.toString(), token1Amount.mul(2).toString());
     assert.equal(event.args.uniPairHeld.toString(), 0);

     const lfi = await pool.getLastFeeIndex();

     assert.equal(event.args.accFeeIndex.toString(), lfi._accFeeIndex.toString());

     const tokenId = BigNumber.from(event.args.tokenId.toString());

     const poolId = await factory.getPool(token0.address, token1.address);

     assert.equal(poolId.toString(), pool.address);

     const pos = await posManager.positions(tokenId);

     const blockNum = await web3.eth.getBlockNumber();

     assert.equal(pos.poolId.toString(), pool.address);
     assert.equal(pos.token0.toString(), token0.address);
     assert.equal(pos.token1.toString(), token1.address);
     assert.equal(pos.tokensHeld0.toString(), token0Amount.mul(2).toString());
     assert.equal(pos.tokensHeld1.toString(), token1Amount.mul(2).toString());
     assert.equal(pos.uniPair.toString(), uniPair.address);
     assert.equal(pos.uniPairHeld.toString(), 0);
     assert.equal(pos.blockNum.toString(), blockNum.toString());
     assert.equal(pos.liquidity.toString(), liquidity.toString());
     assert.equal(pos.rateIndex.toString(), lfi._accFeeIndex.toString());
     });

         it('mint::poolNotFound', async () => {
             await setUp();

             let liquidity = expandTo18Decimals(2);

             await posManager.mint({
                 token0: token0.address,
                 token1: token2.address,
                 liquidity: liquidity,
                 recipient: accounts[0],
                 deadline: constants.MaxUint256
                 }).should.be.rejectedWith('VegaswapV1: POOL_NOT_FOUND');
         });/**/
     });
 });