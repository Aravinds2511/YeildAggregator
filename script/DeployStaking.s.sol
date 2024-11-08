// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Staking} from "src/Strategies/Staking.sol";

contract DeployStaking is Script {
    address public tokenAddress;
    uint256 public duration;
    uint256 public rewardAmount;

    function run() external {
        vm.startBroadcast();
        Staking staking = new Staking(tokenAddress, tokenAddress, duration, rewardAmount);
        vm.stopBroadcast();

        console.log("Staking Contract deployed at: ", address(staking));

        putRewardTokens(staking);
    }

    function putRewardTokens(Staking staking) internal {
        IERC20 rewardToken = staking.rewardsToken();
        uint256 rwdAmount = staking.rewardAmount();
        IERC20(rewardToken).transfer(address(staking), rwdAmount); // try if not do in remix / cast

        staking.notifyRewardAmount(rwdAmount);
    }
}
