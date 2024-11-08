// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {VaultFactory} from "../src/VaultFactory.sol";
import {Vault} from "../src/Vault.sol";
import {ERC20MockToken} from "../src/Mock/ERC20MockToken.sol";

contract TestVaultFactory is Test, VaultFactory {
    VaultFactory factory;
    ERC20MockToken token1;
    ERC20MockToken token2;
    Vault vault1;
    Vault vault2;
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        // Deploy the VaultFactory contract
        factory = new VaultFactory();

        // Deploy two mock ERC20 tokens
        token1 = new ERC20MockToken(1000 ether, address(this), "Token One", "TK1");
        token2 = new ERC20MockToken(1000 ether, address(this), "Token Two", "TK2");
    }

    function testDeployVault() public {
        string memory vaultName = "Vault One";
        string memory vaultSymbol = "V1";

        // Deploy the vault
        vault1 = factory.deployVault(token1, vaultName, vaultSymbol);

        // Check that the vault was added to the vaults array
        uint256 vaultCount = factory.getVaultCount();
        assertEq(vaultCount, 1);

        // Retrieve the vault from the factory
        Vault retrievedVault = factory.getVault(0);
        assertEq(address(vault1), address(retrievedVault));

        // Check that the vault was deployed
        bool isDeployed = factory.isVaultDeployed(vault1);
        assertTrue(isDeployed);

        // Check that the vault's owner is set correctly
        address vaultOwner = vault1.owner();
        assertEq(vaultOwner, address(this));
    }

    function testDeployVaultFromDifferentAccount() public {
        string memory vaultName = "Vault Two";
        string memory vaultSymbol = "V2";

        // Simulate deploying from a different account
        vm.prank(user1);
        vm.expectRevert();
        factory.deployVault(token2, vaultName, vaultSymbol);

        // Check that the vault was added to the vaults array
        uint256 vaultCount = factory.getVaultCount();
        assertEq(vaultCount, 0);
    }

    function testGetVaultCount() public {
        // Initially, the vault count should be zero
        uint256 initialCount = factory.getVaultCount();
        assertEq(initialCount, 0);

        // Deploy two vaults
        factory.deployVault(token1, "Vault One", "V1");
        factory.deployVault(token2, "Vault Two", "V2");

        // Now, the vault count should be 2
        uint256 finalCount = factory.getVaultCount();
        assertEq(finalCount, 2);
    }

    function testGetVaultFromUnderlying() public {
        string memory vaultName = "Vault One";
        string memory vaultSymbol = "V1";

        // Get the expected vault address without deploying
        Vault expectedVault = factory.getVaultFromUnderlying(token1, vaultName, vaultSymbol);

        // At this point, the vault should not be deployed
        bool isDeployedBefore = factory.isVaultDeployed(expectedVault);
        assertFalse(isDeployedBefore);

        // Deploy the vault
        Vault deployedVault = factory.deployVault(token1, vaultName, vaultSymbol);

        // The addresses should match
        assertEq(address(expectedVault), address(deployedVault));

        // Now, the vault should be deployed
        bool isDeployedAfter = factory.isVaultDeployed(deployedVault);
        assertTrue(isDeployedAfter);
    }

    function testIsVaultDeployed() public {
        string memory vaultName = "Vault One";
        string memory vaultSymbol = "V1";

        // Get the expected vault address without deploying
        Vault expectedVault = factory.getVaultFromUnderlying(token1, vaultName, vaultSymbol);

        // At this point, the vault should not be deployed
        bool isDeployedBefore = factory.isVaultDeployed(expectedVault);
        assertFalse(isDeployedBefore);

        // Deploy the vault
        Vault deployedVault = factory.deployVault(token1, vaultName, vaultSymbol);

        // Now, the vault should be deployed
        bool isDeployedAfter = factory.isVaultDeployed(deployedVault);
        assertTrue(isDeployedAfter);
    }

    function testDeployVaultTwiceWithSameAsset() public {
        string memory vaultName = "Vault One";
        string memory vaultSymbol = "V1";

        // Deploy the first vault
        factory.deployVault(token1, vaultName, vaultSymbol);

        // Attempt to deploy a second vault with the same asset
        vm.expectRevert(); // Expect a revert due to CREATE2 collision
        factory.deployVault(token1, vaultName, vaultSymbol);
    }

    function testDeployVaultsWithDifferentAssets() public {
        // Deploy vaults with different assets
        Vault vaultA = factory.deployVault(token1, "Vault A", "VA");
        Vault vaultB = factory.deployVault(token2, "Vault B", "VB");

        // Ensure both vaults are deployed and have different addresses
        assertTrue(factory.isVaultDeployed(vaultA));
        assertTrue(factory.isVaultDeployed(vaultB));
        assert(address(vaultA) != address(vaultB));
    }

    function testDeployVaultRevertsWithInvalidParameters() public {
        // Attempt to deploy a vault with empty name and symbol
        vm.expectRevert(InvalidParameters.selector);
        factory.deployVault(token1, "", "");

        // Attempt to deploy a vault with address zero token
        vm.expectRevert(ZeroAddress.selector);
        factory.deployVault(ERC20(address(0)), "Vault", "V");
    }

    function testFillLast12Bytes() public view {
        // Test the helper function fillLast12Bytes
        bytes32 expectedSalt = bytes32(bytes20(address(token1)));
        bytes32 actualSalt = fillLast12Bytes(address(token1));
        assertEq(expectedSalt, actualSalt);
    }

    function testFromLast20Bytes() public pure {
        // Test the helper function fromLast20Bytes
        bytes32 hash = keccak256(abi.encodePacked("test"));
        address expectedAddress = address(uint160(uint256(hash)));
        address actualAddress = fromLast20Bytes(hash);
        assertEq(expectedAddress, actualAddress);
    }
}
