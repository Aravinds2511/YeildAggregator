// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CompoundStrategy} from "../../src/Strategies/CompoundStrategy.sol";

contract TestCompoundStrategy is Test {
    CompoundStrategy public strategy;

    //Eth mainnet address
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public constant CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    address public constant DAI_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    address public user = makeAddr("user");
    uint256 public initialUserBalance = 100 * 1e8;

    function setUp() public {
        strategy = new CompoundStrategy(IERC20(DAI), CDAI);

        vm.startPrank(DAI_WHALE);
        IERC20(DAI).transfer(user, initialUserBalance);
        vm.stopPrank();

        // Set up approval for strategy contract to spend user DAI
        vm.startPrank(user);
        IERC20(DAI).approve(address(strategy), initialUserBalance);
        vm.stopPrank();
    }

    function testDeposit() public {
        uint256 depositAmount = 10 * 1e8;

        // User deposits DAI into the strategy
        vm.startPrank(user);
        strategy.deposit(depositAmount);
        vm.stopPrank();

        // Check that the user's DAI balance decreased
        uint256 userBalanceAfterDeposit = IERC20(DAI).balanceOf(user);
        assertEq(userBalanceAfterDeposit, initialUserBalance - depositAmount);

        // Check that the strategy's cDAI balance increased
        uint256 strategyCTokenBalance = strategy.getCTokenBalance();
        assertGt(strategyCTokenBalance, 0);

        console.log("Deposit successful. User DAI balance:", userBalanceAfterDeposit);
        console.log("Strategy cToken balance after deposit:", strategyCTokenBalance);
    }

    function testWithdraw() public {
        uint256 depositAmount = 10 * 1e8;

        // User deposits DAI into the strategy
        vm.startPrank(user);
        strategy.deposit(depositAmount);

        // User withdraws DAI from the strategy
        strategy.withdraw(depositAmount);
        vm.stopPrank();

        // Verify the user's DAI balance is back to the initial amount
        uint256 userBalanceAfterWithdraw = IERC20(DAI).balanceOf(user);
        assertEq(userBalanceAfterWithdraw, initialUserBalance);

        // Verify the strategy's cDAI balance is zero or minimal after withdrawal
        uint256 strategyCTokenBalanceAfterWithdraw = strategy.getCTokenBalance();
        assert(strategyCTokenBalanceAfterWithdraw <= 1);

        console.log("Withdraw successful. User DAI balance:", userBalanceAfterWithdraw);
        console.log("Strategy cToken balance after withdraw:", strategyCTokenBalanceAfterWithdraw);
    }

    function testBalanceOfUnderlying() public {
        uint256 depositAmount = 10 * 1e8;

        // User deposits DAI into the strategy
        vm.startPrank(user);
        strategy.deposit(depositAmount);
        vm.stopPrank();

        // Check the underlying balance in the Compound protocol
        uint256 underlyingBalance = strategy.balanceOfUnderlying();
        assert(underlyingBalance >= depositAmount);

        console.log("Underlying balance in Compound (DAI):", underlyingBalance);
    }

    function testGetCTokenBalance() public {
        uint256 depositAmount = 10 * 1e8;

        // User deposits DAI into the strategy
        vm.startPrank(user);
        strategy.deposit(depositAmount);
        vm.stopPrank();

        // Check the cToken balance after deposit
        uint256 cTokenBalance = strategy.getCTokenBalance();
        assertGt(cTokenBalance, 0);

        console.log("cToken balance after deposit:", cTokenBalance);
    }

    function testHarvest() public {
        // Compound does not have separate rewards, so calling harvest should have no effect
        // We are testing to confirm that calling `harvest()` doesn’t revert or cause errors.

        vm.prank(user);
        strategy.harvest();

        console.log("Harvest function executed successfully.");
    }
}
