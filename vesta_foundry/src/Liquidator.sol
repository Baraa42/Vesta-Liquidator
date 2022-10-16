// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../interfaces/IVault.sol";
import "../interfaces/IFlashLoanRecipient.sol";
import "../interfaces/ITroveManager.sol";
import "../interfaces/IStabilityPool.sol";
import "../interfaces/IGMXRouter.sol";
import "../interfaces/ICurve.sol";
import "./BalancerSwapper.sol";

import "forge-std/Test.sol";

contract Liquidator is IFlashLoanRecipient, Test {
    IERC20 private constant WETH =
        IERC20(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    IERC20 private constant FRAX =
        IERC20(0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F);

    address private owner;
    IVault private immutable vault;
    ITroveManager private immutable troveManager;
    IStabilityPool private immutable stabilityPool;
    BalancerSwapper private immutable swapper;
    IGMXRouter private immutable gmxrouter;
    ICurve private immutable vst_frax;

    bytes32 private constant ETH_USDC_WBTC_POOL_ID =
        0x64541216bafffeec8ea535bb71fbc927831d0595000100000000000000000002;
    bytes32 private constant VST_DAI_USDT_USDC =
        0x5a5884fc31948d59df2aeccca143de900d49e1a300000000000000000000006f;

    IERC20 private constant VST =
        IERC20(0x64343594Ab9b56e99087BfA6F2335Db24c2d1F17);

    constructor(
        IVault vault_,
        ITroveManager troveManager_,
        IStabilityPool stabilityPool_,
        IGMXRouter gmxrouter_,
        ICurve vst_frax_
    ) {
        vault = vault_;
        troveManager = troveManager_;
        stabilityPool = stabilityPool_;
        gmxrouter = gmxrouter_;
        vst_frax = vst_frax_;
        owner = msg.sender;
        swapper = new BalancerSwapper(vault);
        emit log_named_address("swapper:", address(swapper));
        uint num = swapper.num();
        emit log_uint(num);
    }

    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) internal {
        vault.flashLoan(address(this), tokens, amounts, userData);
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault));
        emit log("receiving flash loan");
        uint256 depositAmount = VST.balanceOf(address(this));
        VST.approve(address(stabilityPool), depositAmount);
        emit log("provideToSP");
        stabilityPool.provideToSP(depositAmount);
        uint256 n = abi.decode(userData, (uint));
        emit log("liquidateTroves");
        troveManager.liquidateTroves(address(0), n);
        emit log("withdrawFromSP");
        stabilityPool.withdrawFromSP(type(uint).max);
        swapEthToVST();
        uint256 repayAmount = amounts[0] + feeAmounts[0];
        VST.transfer(address(vault), repayAmount);
        emit log_named_uint("vst bal", VST.balanceOf(address(this)) / 10**18);
        VST.transfer(owner, VST.balanceOf(address(this)));

        emit log_named_uint("eth bal", address(this).balance);
        if (address(this).balance > 0) {
            payable(owner).transfer(address(this).balance);
        }
    }

    function balancerSwap() internal returns (int256[] memory) {
        emit log("balancerSwap");
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
        return
            vault.batchSwap{value: address(this).balance}(
                IVault.SwapKind.GIVEN_IN,
                swaps,
                assets,
                funds,
                limits,
                deadline
            );
    }

    function swapEthToVST() internal {
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(FRAX);
        gmxrouter.swapETHToTokens{value: address(this).balance}(
            path,
            0,
            address(this)
        );
        uint frax_balance = FRAX.balanceOf(address(this));
        FRAX.approve(address(vst_frax), frax_balance);
        vst_frax.exchange(1, 0, frax_balance, 0, address(this));
    }

    // 1. Flash loan a lot of VST
    // 2. Deposit to stability Pool
    // 3. Liquidate borrower
    // 4. Withdraw from pool
    // 5. swap ETH for VST
    // 6. repay debt
    // 7. send rest of balance to owner

    function liquidate(uint256 n) public {
        // 1. Flash loan a lot of VST
        // How much should I borrow ?
        emit log("Starting");
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = VST;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 30000 * 1e18;
        bytes memory userData = abi.encode(n);
        emit log("making flash loan");
        makeFlashLoan(tokens, amounts, userData);
    }

    receive() external payable {}
}

// 1.
