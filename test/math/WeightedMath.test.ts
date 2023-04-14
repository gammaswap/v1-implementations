import { Contract, BigNumber } from "ethers";

import { ethers } from "hardhat";
import { expect } from "chai";

describe("WeightedMath", function () {
  let math: Contract;
  let mathFactory: any;
  const ONE = BigNumber.from(10).pow(18);
  const TENTH = BigNumber.from(10).pow(17);

  function expectEqualWithError(actual: BigNumber, expected: BigNumber) {
    const MAX_ERROR = BigNumber.from(10).pow(15); // Max error

    const error = actual.sub(expected).abs();
    expect(error.lte(MAX_ERROR));
  }

  before(async function () {
    const fixedPointFactory = await ethers.getContractFactory("FixedPoint");
    const fixedPoint = await fixedPointFactory.deploy();
    mathFactory = await ethers.getContractFactory("TestWeightedMath", {
      libraries: {
        FixedPoint: fixedPoint.address,
      },
    });
    math = await mathFactory.deploy();
  });

  context("Testing Calculate Invariant", () => {
    context("Zero Invariant", () => {
      it("Reverts for Zero Invariant with BAL#311", async () => {
        await expect(
          math._calculateInvariant([BigNumber.from(1)], [0])
        ).to.be.revertedWith("BAL#311");
      });
    });

    context("Two Tokens", () => {
      it("Returns Correct Invariant #1", async () => {
        const normalizedWeights = [
          BigNumber.from(2).mul(TENTH),
          BigNumber.from(8).mul(TENTH),
        ];
        const balances = [
          BigNumber.from(10).mul(ONE),
          BigNumber.from(12).mul(ONE),
        ];
        const result = await math._calculateInvariant(
          normalizedWeights,
          balances
        );
        const expectedInvariant = BigNumber.from("11570310048031528000");
        expectEqualWithError(result, expectedInvariant);
      });

      it("Returns Correct Invariant #2", async () => {
        const normalizedWeights = [
          BigNumber.from(5).mul(TENTH),
          BigNumber.from(5).mul(TENTH),
        ];
        const balances = [
          BigNumber.from(12).mul(ONE),
          BigNumber.from(12).mul(ONE),
        ];
        const result = await math._calculateInvariant(
          normalizedWeights,
          balances
        );
        const expectedInvariant = BigNumber.from(12).mul(ONE);
        expectEqualWithError(result, expectedInvariant);
      });
    });
  });
});
