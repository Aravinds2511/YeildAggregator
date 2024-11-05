// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract Strategy {
    IERC20 public immutable underlyingAsset;

    constructor(IERC20 _underlyingAsset) {
        underlyingAsset = _underlyingAsset;
    }

    /**
     * @notice Deposit a specified amount of underlying asset into the strategy.
     * @param amount The amount of underlying asset to deposit.
     */
    function deposit(uint256 amount) external virtual;

    /**
     * @notice Withdraw a specified amount of underlying asset from the strategy.
     * @param amount The amount of underlying asset to withdraw.
     */
    function withdraw(uint256 amount) external virtual;

    /**
     * @notice Harvest profit amount of underlying asset from the strategy.
     */
    function harvest() external virtual;

    /**
     * @notice Returns the total balance of the underlying asset managed by the strategy.
     * @return The balance in the underlying asset.
     */
    function balanceOfUnderlying() public view virtual returns (uint256);
}
