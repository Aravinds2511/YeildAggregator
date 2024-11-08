// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Strategy} from "../Strategy.sol";
import {IStakingPool} from "src/Strategies/Interface/IStakingPool.sol";

contract SimpleStakingStrategy is Strategy, Ownable {
    error TransferFailed();

    IStakingPool public stakingPool;
    IERC20 public immutable UNDERLYING;

    constructor(IERC20 _underlyingAsset, address _stakingPool, address owner)
        Strategy(_underlyingAsset)
        Ownable(owner)
    {
        stakingPool = IStakingPool(_stakingPool);
        UNDERLYING = _underlyingAsset;
    }

    /**
     * @notice Deposit assets into the staking pool.
     * @param amount The amount of underlying asset to deposit.
     */
    function deposit(uint256 amount) external override onlyOwner {
        if (!underlyingAsset.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();
        underlyingAsset.approve(address(stakingPool), amount);
        stakingPool.stake(amount);
    }

    /**
     * @notice Withdraw assets from the staking pool.
     * @param amount The amount of underlying asset to withdraw.
     */
    function withdraw(uint256 amount) external override onlyOwner {
        stakingPool.withdraw(amount);
        if (!underlyingAsset.transfer(msg.sender, amount)) revert TransferFailed();
    }

    /**
     * @notice Harvest profit amount of underlying asset from the strategy.
     */
    function harvest() external override onlyOwner {
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
        uint256 balance = stakingPool.balanceOf(address(this)) + stakingPool.earned(address(this));
        return balance;
    }
}
