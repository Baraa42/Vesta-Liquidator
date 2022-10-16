// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface ITroveManager {
    function liquidate(address _asset, address _borrower) external;

    function liquidateTroves(address _asset, uint256 _n) external;
}
