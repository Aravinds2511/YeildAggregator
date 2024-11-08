// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {SimpleStakingStrategy} from "src/Strategies/SimpleStakingStrategy.sol";

contract DeploySimpleStakingStrategy is Script {
    address public stakingPool;
    address public underlying;
    address public vaultContract;

    function run() external {
        vm.startBroadcast();
        SimpleStakingStrategy simpleStakingStrategy =
            new SimpleStakingStrategy(IERC20(underlying), stakingPool, vaultContract);
        vm.stopBroadcast();

        console.log("SimpleStakingStrategy Contract deployed at: ", address(simpleStakingStrategy));
    }
}
