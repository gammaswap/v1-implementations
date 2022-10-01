// @ts-ignore
import { ethers } from "hardhat";
import { expect } from "chai";
import { BigNumber } from "ethers";

describe("LinearKinkedRateModel", function () {
  let RateModel: any;
  let rateModel: any;
  let baseRate: any;
  let optimalUtilRate: any;
  let slope1: any;
  let slope2: any;
  let ONE: any;

  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    RateModel = await ethers.getContractFactory("TestLinearKinkedRateModel");

    ONE = BigNumber.from(10).pow(18);
    baseRate = ONE.div(100);
    optimalUtilRate = ONE.mul(8).div(10);
    slope1 = ONE.mul(4).div(100);
    slope2 = ONE.mul(75).div(100);

    rateModel = await RateModel.deploy(
      baseRate,
      optimalUtilRate,
      slope1,
      slope2
    );
  });

  function calcBorrowRate(
    lpBalance: BigNumber,
    lpBorrowed: BigNumber
  ): BigNumber {
    const totalLP = lpBorrowed.add(lpBalance);
    const utilizationRate = lpBorrowed.mul(ONE).div(totalLP);
    if (utilizationRate.lte(optimalUtilRate)) {
      const variableRate = utilizationRate.mul(slope1).div(optimalUtilRate);
      return baseRate.add(variableRate);
    } else {
      const utilizationRateDiff = utilizationRate.sub(optimalUtilRate);
      const optimalUtilRateDiff = ONE.sub(optimalUtilRate);
      const variableRate = utilizationRateDiff
        .mul(slope2)
        .div(optimalUtilRateDiff);
      return baseRate.add(slope1).add(variableRate);
    }
  }

  describe("Deployment", function () {
    it("Should set right init params", async function () {
      expect(await rateModel.baseRate()).to.equal(baseRate);
      expect(await rateModel.optimalUtilRate()).to.equal(optimalUtilRate);
      expect(await rateModel.slope1()).to.equal(slope1);
      expect(await rateModel.slope2()).to.equal(slope2);
    });
  });

  describe("Calc Borrow Rate", function () {
    it("lpBalance: 100, lpBorrowed: 50", async function () {
      const lpBalance = ONE.mul(100);
      const lpBorrowed = ONE.mul(50);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 100, lpBorrowed: 90", async function () {
      const lpBalance = ONE.mul(100);
      const lpBorrowed = ONE.mul(90);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 100, lpBorrowed: 99", async function () {
      const lpBalance = ONE.mul(100);
      const lpBorrowed = ONE.mul(99);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 100, lpBorrowed: 100", async function () {
      const lpBalance = ONE.mul(100);
      const lpBorrowed = ONE.mul(100);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 100, lpBorrowed: 1000", async function () {
      const lpBalance = ONE.mul(100);
      const lpBorrowed = ONE.mul(1000);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 1, lpBorrowed: 9999999999", async function () {
      const lpBalance = ONE.mul(1);
      const lpBorrowed = ONE.mul(9999999999);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });

    it("lpBalance: 9999999999, lpBorrowed: 1", async function () {
      const lpBalance = ONE.mul(9999999999);
      const lpBorrowed = ONE.mul(1);
      expect(
        await rateModel.testCalcBorrowRate(lpBalance, lpBorrowed)
      ).to.equal(calcBorrowRate(lpBalance, lpBorrowed));
    });
  });
});
