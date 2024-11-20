# Yield Aggregator

The **Yield Aggregator** is a robust, modular contract designed to manage and allocate funds to multiple yield farming strategies. It complies with the **ERC-4626 Tokenized Vault Standard**, providing a seamless interface for deposits, withdrawals, and yield generation. The vault supports dynamic strategy addition, removal, and reallocation of funds to optimize returns.

---

## 🛠 **How It Works**

### Core Components:

1. **Vault**:

   - Central contract for managing user deposits and delegating assets to various yield farming strategies.
   - Built on the ERC-4626 standard, which tokenizes vault shares for user deposits.
   - Tracks user shares, total assets under management, and the performance of individual strategies.

2. **Strategies**:

   - External contracts implementing specific yield farming logic (e.g., staking, compounding).
   - The Vault interacts with strategies to:
     - Deposit allocated funds.
     - Harvest rewards and reinvest them.
     - Withdraw funds when users redeem their shares.
   - Strategies are modular and can be dynamically added or removed.

3. **ERC-4626**:
   - Provides tokenized shares representing a user's claim in the Vault.
   - Users can deposit assets to mint shares, and redeem shares to withdraw assets.

---

### Workflow:

1. **Deposit**:

   - Users deposit tokens into the Vault.
   - The Vault tokenizes these deposits as **shares** based on the current exchange rate.
   - Deposited funds are distributed equally across active strategies.

2. **Yield Generation**:

   - Active strategies manage the allocated funds to generate rewards.
   - Rewards are harvested periodically and reinvested into the strategies.

3. **Withdrawal**:

   - Users can withdraw assets by redeeming their shares.
   - The Vault retrieves the required assets by withdrawing them proportionally from active strategies.

4. **Strategy Management**:
   - New strategies can be added dynamically by the owner.
   - Strategies can also be removed, with all allocated funds being withdrawn back to the Vault.

---

## 🧱 **Features**

- **Multiple Strategies**: Allocate assets across multiple active strategies to diversify and optimize returns.
- **Harvest and Reinvest**: Periodic harvesting of rewards from strategies, with reinvestment for compounding growth.
- **Dynamic Management**:
  - Add or remove strategies as market conditions change.
  - Reallocate assets among active strategies.
- **ERC-4626 Compatibility**: Simplifies the user experience with tokenized deposits and withdrawals.

---

## 🚀 **Usage**

### 1. Deploying the Vault

1. Deploy the `Vault` contract by specifying:
   - The ERC20 token to be managed (`_asset`).
   - The vault name (`_name`) and symbol (`_symbol`).
   - The owner (`_owner`).

### 2. Adding Strategies

- Use the `addStrategy()` function to register a new strategy.
- The strategy must implement the required interface (`Strategy.sol`).

### 3. Depositing Funds

- Users can call `deposit()` to add funds to the Vault.
- Shares are minted to represent the user's claim in the Vault.

### 4. Harvesting Rewards

- The owner can call `harvest()` to collect and reinvest rewards from all active strategies.

### 5. Withdrawing Funds

- Users can call `withdraw()` to redeem their shares for the underlying assets.
- The Vault automatically withdraws the required amount from active strategies.

---

## 📄 **Contracts Overview**

### Vault.sol

The central contract managing user funds and interacting with strategies. Key functions include:

- **Deposit**: `deposit(uint256 assets, address receiver)`
  - Transfers assets from the user to the Vault.
  - Allocates funds across active strategies.
- **Withdraw**: `withdraw(uint256 assets, address receiver, address owner)`

  - Retrieves the specified amount of assets by withdrawing proportionately from strategies.
  - Burns the corresponding shares from the owner.

- **Harvest**: `harvest()`

  - Collects and reinvests rewards from all active strategies.

- **Add Strategy**: `addStrategy(Strategy strategy)`
  - Adds a new strategy to the Vault.
- **Remove Strategy**: `removeStrategy(Strategy strategy)`

  - Withdraws all funds from the strategy and removes it from the active list.

- **Assets Allocation**: `_allocateAssetsToStrategies(uint256 amount)`
  - Internal function to distribute funds equally among active strategies.

### Strategy.sol

An abstract contract that all strategies must implement. Defines the following core functions:

- `deposit(uint256 amount)`
- `withdraw(uint256 amount)`
- `harvest()`
- `balanceOfUnderlying()`

### ERC-4626 Compliance

The Vault fully adheres to the ERC-4626 standard, including the following functions:

- `totalAssets()`: Returns the total assets managed by the Vault.
- `previewDeposit(uint256 assets)`: Calculates shares for a given deposit.
- `previewWithdraw(uint256 assets)`: Calculates the asset equivalent for a given share amount.

---

## 🧪 **Testing**

### Prerequisites

- Install Foundry: [Foundry Installation Guide](https://book.getfoundry.sh/getting-started/installation.html).

### Run Tests

1. Install dependencies:
   ```bash
   forge install
   ```
2. Execute tests:
   ```bash
   forge test
   ```
