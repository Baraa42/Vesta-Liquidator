// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGMXRouter {
    function swapETHToTokens(
        address[] memory _path,
        uint _minOut,
        address _receiver
    ) external payable;
}
