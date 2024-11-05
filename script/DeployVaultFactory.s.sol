// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {VaultFactory} from "src/VaultFactory.sol";

contract DeployVaultFactory is Script {
    address tokenAddress;

    function run() external {
        vm.startBroadcast();
        VaultFactory vaultFactory = new VaultFactory();
        vm.stopBroadcast();

        console.log("VaultFactory Contract deployed at: ", address(vaultFactory));
    }
}
