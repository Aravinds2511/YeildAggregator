// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CompoundStrategy} from "src/Strategies/CompoundStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICompoundCToken} from "src/Strategies/Interface/ICompoundCToken.sol";

contract DeploySimpleStakingStrategy is Script {
    address public underlying;
    address public cToken;

    function run() external {
        vm.startBroadcast();
        CompoundStrategy compoundStrategy = new CompoundStrategy(IERC20(underlying), ICompoundCToken(cToken));
        vm.stopBroadcast();

        console.log("CompoundStrategy Contract deployed at: ", address(compoundStrategy));
    }
}
