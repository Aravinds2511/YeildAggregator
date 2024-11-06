// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20MockToken} from "src/Mock/ERC20MockToken.sol";

contract DeployVaultFactory is Script {
    uint256 initialSupply;
    address addr;
    string name;
    string symbol;

    function run() external {
        vm.startBroadcast();
        ERC20MockToken token = new ERC20MockToken(initialSupply, addr, name, symbol);
        vm.stopBroadcast();

        console.log("ERC20MockToken Contract deployed at: ", address(token));
    }
}
