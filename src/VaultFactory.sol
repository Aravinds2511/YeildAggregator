// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Vault} from "src/Vault.sol";
import {Strategy} from "./Strategy.sol";

contract VaultFactory is Ownable {
    // Array to hold all deployed vaults
    Vault[] public vaults;

    // Event emitted when a new vault is created
    event VaultCreated(address indexed creator, Vault vaultAddress, IERC20 asset);

    constructor() Ownable(msg.sender) {}

    //Deploys a new Vault contract with a unique address determined by CREATE2.
    function deployVault(ERC20 asset, string memory name, string memory symbol) external returns (Vault vault) {
        // Use CREATE2 to deploy a new Vault contract, with a unique salt derived from the asset's address
        vault = new Vault{salt: fillLast12Bytes(address(asset))}(asset, msg.sender, name, symbol);

        // Store the deployed vault address in the vaults array
        vaults.push(vault);

        // Emit an event to log the vault creation
        emit VaultCreated(msg.sender, vault, asset);
    }

    //Returns the total number of vaults deployed by this factory.
    function getVaultCount() external view returns (uint256) {
        return vaults.length;
    }

    //Returns the vault at a specific index in the vaults array.
    function getVault(uint256 index) external view returns (Vault) {
        require(index < vaults.length, "Invalid index");
        return vaults[index];
    }

    //Computes the expected vault address for a given asset without deploying it.
    function getVaultFromUnderlying(ERC20 underlying, string memory name, string memory symbol)
        external
        view
        returns (Vault)
    {
        return Vault(
            payable(
                fromLast20Bytes(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xFF), // Prefix
                            address(this), // Creator (factory address)
                            fillLast12Bytes(address(underlying)), // Salt derived from asset address
                            keccak256(
                                abi.encodePacked(
                                    type(Vault).creationCode,
                                    abi.encode(underlying, msg.sender, name, symbol) // Constructor arguments for Vault
                                )
                            )
                        )
                    )
                )
            )
        );
    }

    //Checks if a vault at a given address is deployed.
    function isVaultDeployed(Vault vault) external view returns (bool) {
        return address(vault).code.length > 0;
    }

    // Helper function to convert bytes32 hash to address
    function fromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
        return address(uint160(uint256(bytesValue)));
    }

    // Helper function to create a unique salt from an address
    function fillLast12Bytes(address addressValue) internal pure returns (bytes32) {
        return bytes32(bytes20(addressValue));
    }
}
