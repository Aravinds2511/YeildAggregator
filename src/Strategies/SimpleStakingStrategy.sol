// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Strategy} from "../Strategy.sol";
import {IStakingPool} from "src/Strategies/Interface/IStakingPool.sol";

contract SimpleStakingStrategy is Strategy {
    error TransferFailed();

    IStakingPool public stakingPool;
    IERC20 public immutable UNDERLYING;

    constructor(IERC20 _underlyingAsset, IStakingPool _stakingPool) Strategy(_underlyingAsset) {
        stakingPool = _stakingPool;
        UNDERLYING = _underlyingAsset;
    }

    /**
     * @notice Deposit assets into the staking pool.
     * @param amount The amount of underlying asset to deposit.
     */
    function deposit(uint256 amount) external override {
        if (!underlyingAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        underlyingAsset.approve(address(stakingPool), amount);
        stakingPool.stake(amount);
    }

    /**
     * @notice Withdraw assets from the staking pool.
     * @param amount The amount of underlying asset to withdraw.
     */
    function withdraw(uint256 amount) external override {
        stakingPool.withdraw(amount);
        if (!underlyingAsset.transfer(msg.sender, amount)) revert TransferFailed();
    }

    /**
     * @notice Harvest profit amount of underlying asset from the strategy.
     */
    function harvest() external override {
        uint256 beforeBalance = UNDERLYING.balanceOf(address(this));
        stakingPool.getReward();
        uint256 afterBalance = UNDERLYING.balanceOf(address(this));
        uint256 amount = afterBalance - beforeBalance;
        if (!underlyingAsset.transfer(msg.sender, amount)) revert TransferFailed();
    }

    /**
     * @notice Returns the balance of the underlying asset in the staking pool.
     * @return The balance in the underlying asset.
     */
    function balanceOfUnderlying() public view override returns (uint256) {
        return stakingPool.balanceOf(address(this));
    }
}
