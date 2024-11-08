// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Vault} from "../src/Vault.sol";
import {Staking} from "../src/Strategies/Staking.sol";
import {SimpleStakingStrategy} from "../src/Strategies/SimpleStakingStrategy.sol";
import {ERC20MockToken} from "../src/Mock/ERC20MockToken.sol";

contract TestVault is Test {
    Vault vault;
    ERC20MockToken underlying;
    SimpleStakingStrategy strategy1;
    SimpleStakingStrategy strategy2;
    Staking stakingPool1;
    Staking stakingPool2;

    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    uint256 initialSupply = 1_000_000 ether;
    uint256 stakingDuration = 7 days;
    uint256 rewardAmount = 1000 ether;

    function setUp() public {
        // Deploy the underlying asset (e.g., DAI or other ERC20)
        underlying = new ERC20MockToken(1_000_000 ether, user1, "Staking Token", "STK");

        // Deploy the Vault contract
        vault = new Vault(IERC20(underlying), address(this), "Vault Token", "VT");

        // Deploy the staking pool
        stakingPool1 = new Staking(address(underlying), address(underlying), stakingDuration, rewardAmount);
        vm.prank(user1);
        underlying.transfer(address(stakingPool1), rewardAmount);
        stakingPool1.notifyRewardAmount(rewardAmount);

        // Deploy the staking pool2
        stakingPool2 = new Staking(address(underlying), address(underlying), stakingDuration, rewardAmount);
        vm.prank(user1);
        underlying.transfer(address(stakingPool2), rewardAmount);
        stakingPool2.notifyRewardAmount(rewardAmount);

        // Deploy strategies and approve vault to interact with them
        strategy1 = new SimpleStakingStrategy(IERC20(underlying), address(stakingPool1), address(vault));
        strategy2 = new SimpleStakingStrategy(IERC20(underlying), address(stakingPool2), address(vault));
    }

    function testAddStrategy() public {
        // Adding strategy
        vault.addStrategy(strategy1);

        // Verify strategy is active
        (bool active, uint256 balance) = vault.strategies(strategy1);
        assertTrue(active);
        assertEq(balance, 0);
    }

    function testDeposit() public {
        vault.addStrategy(strategy1);
        vault.addStrategy(strategy2);
        uint256 depositAmount = 100 ether;

        // Approve the vault to spend user1's tokens
        vm.prank(user1);
        underlying.approve(address(vault), depositAmount);

        // Execute the deposit
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);

        // Verify shares minted
        assertEq(shares, vault.previewDeposit(depositAmount));
        assertEq(vault.balanceOf(user1), shares);
    }

    function testDepositZeroAmount() public {
        vm.expectRevert();
        vm.prank(user1);
        vault.deposit(0, user1);
    }

    function testAddStrategyAlreadyActive() public {
        vault.addStrategy(strategy1);

        vm.expectRevert(Vault.StrategyAlreadyActive.selector);
        vault.addStrategy(strategy1);
    }

    function testRemoveStrategy() public {
        vault.addStrategy(strategy1);
        vault.removeStrategy(strategy1);

        // Verify strategy is inactive
        (bool active,) = vault.strategies(strategy1);
        assertFalse(active);
    }

    function testRemoveStrategyNotActive() public {
        vm.expectRevert(Vault.StrategyNotActive.selector);
        vault.removeStrategy(strategy1);
    }

    function testAllocateAssetsToStrategies() public {
        uint256 depositAmount = 100 ether;

        // Prepare strategies
        vault.addStrategy(strategy1);
        vault.addStrategy(strategy2);

        // Deposit and allocate assets
        vm.startPrank(user1);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Check balances of each strategy
        (, uint256 balance1) = vault.strategies(strategy1);
        (, uint256 balance2) = vault.strategies(strategy2);
        assertEq(balance1, depositAmount / 2);
        assertEq(balance2, depositAmount / 2);
    }

    function testWithdraw() public {
        vault.addStrategy(strategy1);
        vault.addStrategy(strategy2);

        uint256 depositAmount = 100 ether;
        uint256 withdrawAmount = 50 ether;

        // Approve and deposit
        vm.startPrank(user1);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);

        uint256 balanceOfUserBf = underlying.balanceOf(user1);

        // Withdraw
        vault.withdraw(withdrawAmount, user1, user1);
        vm.stopPrank();

        uint256 balanceOfUser = underlying.balanceOf(user1);

        // Check resulting balances
        assertEq(balanceOfUser - balanceOfUserBf, withdrawAmount);
        assertEq(vault.balanceOf(user1), vault.previewWithdraw(withdrawAmount));
    }

    function testWithdrawInsufficientShares() public {
        vm.expectRevert(Vault.InsufficientShares.selector);
        vm.prank(user1);
        vault.withdraw(100 ether, user1, user1);
    }

    function testTotalAssets() public {
        uint256 depositAmount = 100 ether;

        // Prepare strategies
        vault.addStrategy(strategy1);
        vault.addStrategy(strategy2);
        vm.stopPrank();

        // Deposit and allocate assets
        vm.startPrank(user1);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, user1);
        vm.stopPrank();

        // Calculate total assets
        assertEq(vault.totalAssets(), depositAmount);
    }

    function testHarvest() public {
        vault.addStrategy(strategy1);
        vault.addStrategy(strategy2);

        uint256 depositAmount = 100 ether;

        vm.prank(user1);
        underlying.approve(address(vault), depositAmount);

        // Execute the deposit
        vm.prank(user1);
        uint256 shares = vault.deposit(depositAmount, user1);

        // Move forward in time
        vm.warp(block.timestamp + 1 days);

        // Harvest and verify total rewards
        vault.harvest();

        console.log("TotalAssets :", vault.totalAssets());
        assertGt(vault.totalAssets(), depositAmount);

        uint256 assets = vault.previewRedeem(shares);
        console.log("assets", assets);
        assertGt(assets, depositAmount);
    }

    function testDecimals() public view {
        assertEq(vault.decimals(), underlying.decimals());
    }
}
