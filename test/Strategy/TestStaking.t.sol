// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {Staking} from "../../src/Strategies/Staking.sol";
import {ERC20MockToken} from "../../src/Mock/ERC20MockToken.sol";

contract TestStaking is Test {
    Staking staking;
    ERC20MockToken stakingToken;
    ERC20MockToken rewardsToken;
    address owner = address(this);
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint256 initialSupply = 1_000_000 ether;
    uint256 stakingDuration = 7 days;
    uint256 rewardAmount = 100_000 ether;

    function setUp() public {
        // Deploy mock tokens
        stakingToken = new ERC20MockToken(initialSupply, owner, "Staking Token", "STK");
        rewardsToken = new ERC20MockToken(initialSupply, owner, "Rewards Token", "RWD");

        // Deploy the Staking contract
        staking = new Staking(address(stakingToken), address(rewardsToken), stakingDuration, rewardAmount);

        // Transfer rewards to the staking contract
        rewardsToken.transfer(address(staking), rewardAmount);
    }

    function testInitialState() public {
        staking.notifyRewardAmount(rewardAmount);
        // Check initial parameters
        assertEq(address(staking.stakingToken()), address(stakingToken));
        assertEq(address(staking.rewardsToken()), address(rewardsToken));
        assertEq(staking.duration(), stakingDuration);
        assertEq(staking.finishAt(), block.timestamp + stakingDuration);
        assertEq(staking.rewardRate(), rewardAmount / stakingDuration);
    }

    function testStake() public {
        uint256 stakeAmount = 1_000 ether;

        // Approve staking contract to spend user's tokens
        stakingToken.approve(address(staking), stakeAmount);

        // Stake tokens
        staking.stake(stakeAmount);

        // Check balances and totals
        assertEq(staking.balanceOf(owner), stakeAmount);
        assertEq(staking.totalSupply(), stakeAmount);
        assertEq(stakingToken.balanceOf(owner), initialSupply * 1e18 - stakeAmount);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount);
    }

    function testStakeFromUser() public {
        uint256 stakeAmount = 500 ether;

        // Mint tokens to user1 and approve
        stakingToken.mint(user1, stakeAmount);
        vm.prank(user1);
        stakingToken.approve(address(staking), stakeAmount);

        // Stake tokens as user1
        vm.prank(user1);
        staking.stake(stakeAmount);

        // Check balances and totals
        assertEq(staking.balanceOf(user1), stakeAmount);
        assertEq(staking.totalSupply(), stakeAmount);
        assertEq(stakingToken.balanceOf(user1), 0);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount);
    }

    function testWithdraw() public {
        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward time to accumulate rewards
        vm.warp(block.timestamp + 1 days);

        // Withdraw half of the stake
        uint256 withdrawAmount = 500 ether;
        staking.withdraw(withdrawAmount);

        // Check balances and totals
        assertEq(staking.balanceOf(owner), stakeAmount - withdrawAmount);
        assertEq(staking.totalSupply(), stakeAmount - withdrawAmount);
        assertEq(stakingToken.balanceOf(owner), initialSupply * 1e18 - stakeAmount + withdrawAmount);
        assertEq(stakingToken.balanceOf(address(staking)), stakeAmount - withdrawAmount);
    }

    function testEarned() public {
        staking.notifyRewardAmount(rewardAmount);

        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        // Calculate expected rewards
        uint256 expectedReward = rewardAmount / 7;

        // Get earned rewards
        uint256 earnedReward = staking.earned(owner);

        // Allow for small rounding errors
        assertApproxEqAbs(earnedReward, expectedReward, 80000);
    }

    function testGetReward() public {
        staking.notifyRewardAmount(rewardAmount);

        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        uint256 rewardBalanceBf = rewardsToken.balanceOf(owner);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        // Get earned rewards before claiming
        uint256 earnedReward = staking.earned(owner);
        assertGt(earnedReward, 0);

        // Claim rewards
        staking.getReward();

        // Check rewards balance
        uint256 rewardBalance = rewardsToken.balanceOf(owner);
        assertEq(rewardBalance - rewardBalanceBf, earnedReward);

        // Ensure rewards are reset
        assertEq(staking.rewards(owner), 0);
    }

    function testMultipleStakers() public {
        staking.notifyRewardAmount(rewardAmount);
        uint256 stakeAmount1 = 1_000 ether;
        uint256 stakeAmount2 = 2_000 ether;

        // Mint and approve tokens for user1 and user2
        stakingToken.mint(user1, stakeAmount1);
        stakingToken.mint(user2, stakeAmount2);
        vm.prank(user1);
        stakingToken.approve(address(staking), stakeAmount1);
        vm.prank(user2);
        stakingToken.approve(address(staking), stakeAmount2);

        // Users stake tokens at different times
        vm.prank(user1);
        staking.stake(stakeAmount1);
        vm.warp(block.timestamp + 1 days);
        vm.prank(user2);
        staking.stake(stakeAmount2);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        uint256 rewardUser1 = (
            (stakeAmount1 * (staking.rewardPerToken() - staking.userRewardPerTokenPaid(user1))) / 1e18
        ) + staking.rewards(user1);
        uint256 rewardUser2 = (
            (stakeAmount2 * (staking.rewardPerToken() - staking.userRewardPerTokenPaid(user2))) / 1e18
        ) + staking.rewards(user2);

        // Users claim rewards
        vm.prank(user1);
        staking.getReward();
        vm.prank(user2);
        staking.getReward();

        // Check rewards balances
        uint256 balanceUser1 = rewardsToken.balanceOf(user1);
        uint256 balanceUser2 = rewardsToken.balanceOf(user2);

        // Allow for small rounding errors
        assertEq(balanceUser1, rewardUser1);
        assertEq(balanceUser2, rewardUser2);
    }

    function testSetRewardsDuration() public {
        staking.notifyRewardAmount(rewardAmount);
        uint256 newDuration = 14 days;

        // Attempt to set duration before rewards finish
        vm.expectRevert();
        staking.setRewardsDuration(newDuration);

        // Fast forward time to finish rewards
        vm.warp(block.timestamp + stakingDuration + 1);

        // Set new rewards duration
        staking.setRewardsDuration(newDuration);
        assertEq(staking.duration(), newDuration);
    }

    function testNotifyRewardAmount() public {
        uint256 newRewardAmount = 200_000 ether;

        // Fast forward time to finish rewards
        vm.warp(block.timestamp + stakingDuration + 1);

        // Transfer additional rewards to staking contract
        rewardsToken.mint(address(staking), newRewardAmount);

        // Notify new reward amount
        staking.notifyRewardAmount(newRewardAmount);

        // Check updated parameters
        assertEq(staking.rewardRate(), newRewardAmount / staking.duration());
        assertEq(staking.finishAt(), block.timestamp + staking.duration());
    }

    function testRewardPerToken() public {
        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Fast forward time
        vm.warp(block.timestamp + 1 days);

        // Calculate expected reward per token
        uint256 expectedRewardPerToken = (staking.rewardRate() * 1 days * 1e18) / stakeAmount;

        // Get reward per token
        uint256 rewardPerToken = staking.rewardPerToken();

        // Allow for small rounding errors
        assertApproxEqAbs(rewardPerToken, expectedRewardPerToken, 1);
    }

    function testLastTimeRewardApplicable() public {
        // Fast forward time beyond finishAt
        vm.warp(staking.finishAt() + 1 days);
        uint256 lastTime = staking.lastTimeRewardApplicable();
        assertEq(lastTime, staking.finishAt());
    }

    function testCannotStakeZero() public {
        // Attempt to stake zero tokens
        stakingToken.approve(address(staking), 0);
        vm.expectRevert();
        staking.stake(0);
    }

    function testCannotWithdrawZero() public {
        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Attempt to withdraw zero tokens
        vm.expectRevert();
        staking.withdraw(0);
    }

    function testCannotWithdrawMoreThanStaked() public {
        uint256 stakeAmount = 1_000 ether;

        // Stake tokens
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Attempt to withdraw more than staked
        vm.expectRevert(); // Underflow error
        staking.withdraw(stakeAmount + 1);
    }

    function testStakeAfterRewardsFinished() public {
        // Fast forward time to finish rewards
        vm.warp(block.timestamp + stakingDuration + 1);

        // Stake tokens after rewards have finished
        uint256 stakeAmount = 1_000 ether;
        stakingToken.approve(address(staking), stakeAmount);
        staking.stake(stakeAmount);

        // Earned rewards should be zero
        uint256 earnedRewards = staking.earned(owner);
        assertEq(earnedRewards, 0);
    }
}
