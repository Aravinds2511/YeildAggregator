// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Staking} from "../../src/Strategies/Staking.sol";
import {ERC20MockToken} from "../../src/Mock/ERC20MockToken.sol";
import {FailingERC20} from "../../src/Mock/FailingERC20.sol";
import {SimpleStakingStrategy} from "../../src/Strategies/SimpleStakingStrategy.sol";
import {IStakingPool} from "../../src/Strategies/Interface/IStakingPool.sol";

contract TestSimpleStakingStrategy is Test {
    ERC20MockToken underlyingAsset;
    SimpleStakingStrategy strategy;
    Staking stakingPool;
    address user = makeAddr("user");
    address nonOwner = makeAddr("nonOwner");

    uint256 initialSupply = 1_000_000 ether;
    uint256 stakingDuration = 7 days;
    uint256 rewardAmount = 100_000 ether;

    function setUp() public {
        // Deploy the underlying asset
        underlyingAsset = new ERC20MockToken(1_000_000 ether, user, "Staking Token", "STK");

        // Deploy the staking pool
        stakingPool = new Staking(address(underlyingAsset), address(underlyingAsset), stakingDuration, rewardAmount);
        vm.prank(user);
        underlyingAsset.transfer(address(stakingPool), rewardAmount);
        stakingPool.notifyRewardAmount(rewardAmount);

        // Deploy the strategy
        strategy = new SimpleStakingStrategy(IERC20(underlyingAsset), address(stakingPool), user);
    }

    function testDeposit() public {
        vm.startPrank(user);
        uint256 depositAmount = 1_000 ether;

        // Approve Strategy contract
        underlyingAsset.approve(address(strategy), depositAmount);

        // Call deposit
        strategy.deposit(depositAmount);

        // Check that tokens are staked in the staking pool
        uint256 stakedBalance = stakingPool.balanceOf(address(strategy));
        assertEq(stakedBalance, depositAmount);

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user);
        uint256 depositAmount = 1_000 ether;
        underlyingAsset.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        uint256 userBalanceBf = underlyingAsset.balanceOf(user);

        // Withdraw half the amount
        uint256 withdrawAmount = 500 ether;
        strategy.withdraw(withdrawAmount);

        // Check user's token balance
        uint256 userBalance = underlyingAsset.balanceOf(user);
        assertEq(userBalance - userBalanceBf, withdrawAmount);

        // Check remaining staked balance
        uint256 stakedBalance = stakingPool.balanceOf(address(strategy));
        assertEq(stakedBalance, depositAmount - withdrawAmount);

        vm.stopPrank();
    }

    function testHarvest() public {
        vm.startPrank(user);
        uint256 depositAmount = 1_000 ether;
        underlyingAsset.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        uint256 userBalanceBf = underlyingAsset.balanceOf(user);

        vm.warp(block.timestamp + 1 days);

        // Harvest rewards
        strategy.harvest();

        // Check user's token balance
        uint256 userBalance = underlyingAsset.balanceOf(user);
        console.log("RewardGot: ", userBalance - userBalanceBf);
        assertGt(userBalance - userBalanceBf, 0);

        vm.stopPrank();
    }

    function testBalanceOfUnderlying() public {
        vm.startPrank(user);
        uint256 depositAmount = 1_000 ether;
        underlyingAsset.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        uint256 userBalanceBf = underlyingAsset.balanceOf(user);
        // Move forward to one day
        vm.warp(block.timestamp + 1 days);

        // Harvest rewards
        strategy.harvest();

        // Check user's token balance
        uint256 userBalance = underlyingAsset.balanceOf(user);
        uint256 rewardGot = userBalance - userBalanceBf;

        //reinvest the reward
        underlyingAsset.approve(address(strategy), rewardGot);
        strategy.deposit(rewardGot);
        vm.stopPrank();

        // Check balanceOfUnderlying
        uint256 balance = strategy.balanceOfUnderlying();
        assertEq(balance, depositAmount + rewardGot);
    }

    function testDepositInsufficientBalance() public {
        vm.startPrank(user);
        uint256 depositAmount = underlyingAsset.balanceOf(user) + 1; // Exceeds user balance
        underlyingAsset.approve(address(strategy), depositAmount);

        // Expect revert due to insufficient balance
        vm.expectRevert();
        strategy.deposit(depositAmount);
        vm.stopPrank();
    }

    function testWithdrawMoreThanStaked() public {
        vm.startPrank(user);
        uint256 depositAmount = 1_000 ether;
        underlyingAsset.approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);

        // Attempt to withdraw more than staked
        uint256 withdrawAmount = 2_000 ether;

        // Expect revert due to insufficient staked balance
        vm.expectRevert();
        strategy.withdraw(withdrawAmount);
        vm.stopPrank();
    }

    function testTransferFailedOnDeposit() public {
        // Deploy a token that always fails on transfer
        FailingERC20 failingToken = new FailingERC20(1_000_000 ether, user, "Fail Token", "FAIL");

        // Deploy a new strategy with the failing token
        SimpleStakingStrategy failingStrategy =
            new SimpleStakingStrategy(IERC20(failingToken), address(stakingPool), user);

        // User approves the failing strategy
        vm.startPrank(user);
        failingToken.approve(address(strategy), 1_000 ether);

        // Expect revert due to transfer failure
        vm.expectRevert(SimpleStakingStrategy.TransferFailed.selector);
        failingStrategy.deposit(1_000 ether);
        vm.stopPrank();
    }

    function testTransferFailWhenInteractingByOtherUser() public {
        vm.prank(user);
        underlyingAsset.mint(nonOwner, 1_000 ether);

        vm.startPrank(nonOwner);
        uint256 depositAmount = 1_000 ether;
        underlyingAsset.approve(address(strategy), depositAmount);

        vm.expectRevert();
        strategy.deposit(depositAmount);
        vm.stopPrank();
    }
}
