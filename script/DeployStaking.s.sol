// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Staking} from "src/Strategies/Staking.sol";

contract DeployStaking is Script {
    address public tokenAddress;
    uint256 public duration;

    function run() external {
        vm.startBroadcast();
        Staking staking = new Staking(tokenAddress, tokenAddress, duration);
        vm.stopBroadcast();

        console.log("Staking Contract deployed at: ", address(staking));
    }
}
