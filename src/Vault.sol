// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {Strategy} from "./Strategy.sol";

/**
 * @title MultiStrategyYieldVault
 * @dev ERC-4626 compliant vault with multiple strategies.
 */
contract Vault is ERC4626, Ownable {
    // Custom Errors
    error ZeroAmountNotAllowed();
    error NotValidAddress();
    error StrategyAlreadyActive();
    error StrategyNotActive();
    error NoActiveStrategies();
    error InsufficientAssets();
    error InsufficientShares();

    struct StrategyData {
        bool active;
        uint256 balance; // Amount allocated to this strategy
    }

    // Underlying asset (e.g., DAI etc.. or custom tokens)
    IERC20 public immutable UNDERLYING;

    // uint256 public totalAmountWithProfits;

    // Mapping from Strategy to its data
    mapping(Strategy => StrategyData) public strategies;
    Strategy[] public activeStrategies;

    // Events
    event StrategyAdded(address indexed user, Strategy indexed strategy);
    event StrategyRemoved(address indexed user, Strategy indexed strategy);
    event AssetsAllocatedToStrategies(uint256 totalAmount);
    event Harvested(uint256 totalRewards);

    /**
     * @dev Constructor initializes the vault with the underlying asset and token details.
     * @param _asset The underlying ERC20 asset.
     * @param _name The name of the vault token.
     * @param _symbol The symbol of the vault token.
     */
    constructor(IERC20 _asset, address _owner, string memory _name, string memory _symbol)
        ERC4626(_asset)
        ERC20(_name, _symbol)
        Ownable(_owner)
    {
        UNDERLYING = _asset;
    }

    /**
     * @dev Deposits assets into the vault and allocates equally among strategies.
     */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        if (assets <= 0) revert ZeroAmountNotAllowed();
        if (receiver == address(0)) revert NotValidAddress();

        // Transfer assets from sender to vault
        UNDERLYING.transferFrom(msg.sender, address(this), assets);

        // Mint shares to receiver based on the exchange rate
        uint256 shares = previewDeposit(assets);
        _mint(receiver, shares);

        // Allocate assets to strategies
        _allocateAssetsToStrategies(assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        return shares;
    }

    /**
     * @dev Withdraws assets from the vault proportionate to the user's shares.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override returns (uint256) {
        if (assets <= 0) revert ZeroAmountNotAllowed();
        if (receiver == address(0)) revert NotValidAddress();
        if (owner == address(0)) revert NotValidAddress();

        uint256 shares = previewWithdraw(assets); // Calculate shares to burn for the asset amount
        if(balanceOf(owner) < shares) revert InsufficientShares();

        // Burn shares from the owner
        _burn(owner, shares);

        // Withdraw proportionate assets from strategies
        _withdrawFromStrategies(assets);

        // Transfer assets to receiver
        UNDERLYING.transfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        return shares;
    }

    /**
     * @dev Harvests rewards from all strategies and reinvests them.
     */
    function harvest() external onlyOwner {
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy strategy = activeStrategies[i];
            if (strategies[strategy].active) {
                uint256 beforeBalance = UNDERLYING.balanceOf(address(this));

                try strategy.harvest() {
                    // This will execute harvest if implemented; no error if not.
                } catch {
                    // Catch any failure in case `harvest` does nothing or isn't implemented.
                    continue;
                }

                uint256 afterBalance = UNDERLYING.balanceOf(address(this));
                uint256 rewards = afterBalance - beforeBalance;

                if (rewards > 0) {
                    // Reinvest rewards into the strategy
                    strategies[strategy].balance += rewards;
                    if (UNDERLYING.allowance(address(this), address(strategy)) < rewards) {
                        UNDERLYING.approve(address(strategy), rewards);
                    }
                    strategy.deposit(rewards);
                    totalRewards += rewards;
                }
            }
        }

        emit Harvested(totalRewards);
    }

    /**
     * @dev Adds a new strategy to the vault.
     */
    function addStrategy(Strategy strategy) external onlyOwner {
        if (strategies[strategy].active) revert StrategyAlreadyActive();
        strategies[strategy] = StrategyData({active: true, balance: 0});
        activeStrategies.push(strategy);
        emit StrategyAdded(msg.sender, strategy);
    }

    /**
     * @dev Removes a strategy from the vault.
     */
    function removeStrategy(Strategy strategy) external onlyOwner {
        if (!strategies[strategy].active) revert StrategyNotActive();

        // Withdraw all funds from the strategy
        uint256 strategyBalance = strategies[strategy].balance;
        if (strategyBalance > 0) {
            strategy.withdraw(strategyBalance);
            strategies[strategy].balance = 0;
        }
        strategies[strategy].active = false;

        // Remove strategy from active strategies array
        for (uint256 i = 0; i < activeStrategies.length; i++) {
            if (activeStrategies[i] == strategy) {
                activeStrategies[i] = activeStrategies[activeStrategies.length - 1];
                activeStrategies.pop();
                break;
            }
        }
        emit StrategyRemoved(msg.sender, strategy);
    }

    /**
     * @dev Internal function to allocate assets equally among active strategies.
     */
    function _allocateAssetsToStrategies(uint256 amount) internal {
        uint256 strategyCount = activeStrategies.length;
        if (strategyCount == 0) revert NoActiveStrategies();

        uint256 amountPerStrategy = amount / strategyCount;

        for (uint256 i = 0; i < strategyCount; i++) {
            Strategy strategy = activeStrategies[i];
            if (strategies[strategy].active) {
                strategies[strategy].balance += amountPerStrategy;
                UNDERLYING.approve(address(strategy), amountPerStrategy);
                strategy.deposit(amountPerStrategy);
            }
        }

        emit AssetsAllocatedToStrategies(amount);
    }

    /**
     * @dev Internal function to withdraw assets from strategies as needed.
     */
    function _withdrawFromStrategies(uint256 amount) internal {
        uint256 remaining = amount;
        if (activeStrategies.length == 0) revert NoActiveStrategies();

        for (uint256 i = activeStrategies.length; i > 0 && remaining > 0; i--) {
            Strategy strategy = activeStrategies[i - 1];
            if (strategies[strategy].active) {
                uint256 strategyBalance = strategies[strategy].balance;
                uint256 withdrawAmount = strategyBalance >= remaining ? remaining : strategyBalance;

                if (withdrawAmount > 0) {
                    strategy.withdraw(withdrawAmount);
                    strategies[strategy].balance -= withdrawAmount;
                    remaining -= withdrawAmount;
                }
            }
        }

        if (remaining > 0) {
            revert InsufficientAssets();
        }
    }

    /**
     * @dev Returns the total assets managed by the vault, including assets in strategies.
     */
    function totalAssets() public view override returns (uint256) {
        uint256 total = UNDERLYING.balanceOf(address(this)); // Vault's own balance

        for (uint256 i = 0; i < activeStrategies.length; i++) {
            Strategy strategy = activeStrategies[i];
            if (strategies[strategy].active) {
                total += strategy.balanceOfUnderlying();
            }
        }
        return total;
    }

    /**
     * @dev Previews the amount of shares that would be minted for a given asset deposit.
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    /**
     * @dev Previews the amount of assets that would be withdrawn for a given share amount.
     */
    function previewWithdraw(uint256 assets) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    // Additional overrides for ERC4626 compliance

    function deposit(uint256 assets) public returns (uint256) {
        return deposit(assets, msg.sender);
    }

    function mint(uint256 shares, address receiver) public override returns (uint256) {
        uint256 assets = previewMint(shares);
        return deposit(assets, receiver);
    }

    function withdraw(uint256 assets) public returns (uint256) {
        return withdraw(assets, msg.sender, msg.sender);
    }

    function redeem(uint256 shares, address receiver, address owner) public override returns (uint256) {
        uint256 assets = previewRedeem(shares);
        return withdraw(assets, receiver, owner);
    }

    function previewMint(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return ERC20(address(UNDERLYING)).decimals();
    }
}
