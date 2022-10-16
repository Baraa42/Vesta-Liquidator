// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../interfaces/IVault.sol";

import "forge-std/Test.sol";

contract BalancerSwapper is Test {
    uint public num = 1;
    address private owner;
    IVault private immutable vault;

    bytes32 private constant ETH_USDC_WBTC_POOL_ID =
        0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002;
    bytes32 private constant VST_DAI_USDT_USDC =
        0x5a5884fc31948d59df2aeccca143de900d49e1a300000000000000000000006f;

    IERC20 private constant VST =
        IERC20(0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17);

    constructor(IVault vault_) {
        vault = vault_;
        owner = msg.sender;
    }

    function swap() external {
        emit log("balancerSwap2");
        require(msg.sender == owner, "!owner");
        IVault.BatchSwapStep[] memory swaps = new IVault.BatchSwapStep[](2);
        swaps[0] = IVault.BatchSwapStep(
            ETH_USDC_WBTC_POOL_ID,
            0,
            1,
            address(this).balance,
            ""
        );
        swaps[1] = IVault.BatchSwapStep(ETH_USDC_WBTC_POOL_ID, 1, 2, 0, "");
        IAsset[] memory assets = new IAsset[](3);
        assets[0] = IAsset(address(0));
        assets[1] = IAsset(address(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8)); // USDC
        assets[2] = IAsset(address(VST));
        IVault.FundManagement memory funds = IVault.FundManagement(
            address(this),
            false,
            payable(address(this)),
            false
        );
        int256[] memory limits = new int256[](3);
        limits[0] = int(address(this).balance);
        limits[1] = 0;
        limits[2] = type(int).min;
        uint256 deadline = block.timestamp;
        emit log("vault.batchSwap");
        vault.batchSwap{value: address(this).balance}(
            IVault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            funds,
            limits,
            deadline
        );
        emit log("owner transfer");
        VST.transfer(owner, VST.balanceOf(address(this)));
        if (address(this).balance > 0) {
            payable(owner).transfer(address(this).balance);
        }
    }

    receive() external payable {}
}

// 1.
