// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingPool {
    function stake(uint256 amount) external;

    function withdraw(uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);

    function getReward() external;
}
