// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../src/Liquidator.sol";
import "forge-std/Test.sol";

contract LiquidatorTest is Test {
    uint256 arbitrumFork;
    Liquidator liquidator;

    function setUp() public {
        string memory url = vm.rpcUrl("arbitrum");
        arbitrumFork = vm.createFork(url, 25157013);
    }

    function testLiquidate() public {
        vm.selectFork(arbitrumFork);
        IVault vault = IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        ITroveManager troveManager = ITroveManager(
            0x100EC08129e0FD59959df93a8b914944A3BbD5df
        );
        IStabilityPool stabilityPool = IStabilityPool(
            0x64cA46508ad4559E1fD94B3cf48f3164B4a77E42
        );
        IGMXRouter gmxrouter = IGMXRouter(
            0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064
        );
        ICurve vst_frax = ICurve(0x59bF0545FCa0E5Ad48E13DA269faCD2E8C886Ba4);

        liquidator = new Liquidator(
            vault,
            troveManager,
            stabilityPool,
            gmxrouter,
            vst_frax
        );
        liquidator.liquidate(281474976710655, 10000 * 1e18);
    }
}
