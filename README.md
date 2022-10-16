# Vesta Flash-Liquidator 
 
 
*A liquidator smart contract for Vesta protocol that earn more from liquidations by flashloaning VST tokens from balancer and depositing to Stability pool* 
 
## How does this work?? 
 
Normal liquidations set the Trove under 110% ICR. Under this condition, thel iquidator earns: $30 + 0.5% of the total collateral, while stability pool depositors take rest of collateral. 
 
Flashloan liquidations allow one to earn more collateral. This liquidation consists of the follwing steps: 
 
- Flashloan VST stable coin from balancer for a no fees at all *(for now)* 
- Deposit the flashloaned stable coin into stability pool, which allows to earn liquidation fees 
- Liquidate the borrower, which yields 30$ + 0.5% Collateral + % of total deposits in stability pool 
- Withdraw VST stable coin and ETH from the pool 
- Swap ETH for VST stable coin (by routing through GMX and Curve) 
- Repay debt on balancer 
- Keep the remaining balance as net profit
