// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

abstract contract AbstractRateModel {

    function calcUtilizationRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual view returns(uint256) {
        uint256 totalInvariant = lpInvariant + borrowedInvariant;
        if(totalInvariant == 0)
            return 0;

        return borrowedInvariant * (10 ** 18) / totalInvariant;
    }

    function calcBorrowRate(uint256 lpInvariant, uint256 borrowedInvariant) internal virtual view returns(uint256);
}
