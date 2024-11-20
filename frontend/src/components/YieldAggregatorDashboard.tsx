'use client';

import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { ethers } from 'ethers';
import { Loader2, MinusCircle, PlusCircle, WalletIcon } from 'lucide-react';
import React, { useEffect, useState } from 'react';

// Import the ABIs
import VaultABI from '@/abis/Vault.json';
import VaultFactoryABI from '@/abis/VaultFactory.json';

interface Vault {
  address: string;
  name: string;
  symbol: string;
  totalAssets: string;
  apy: string;
  strategies: number;
  tvl: string;
}

interface VaultContract extends ethers.Contract {
  name: () => Promise<string>;
  symbol: () => Promise<string>;
  totalAssets: () => Promise<bigint>;
  decimals: () => Promise<number>;
  balanceOf: (account: string) => Promise<bigint>;
  getStrategiesCount: () => Promise<bigint>;
  strategies: (strategyAddress: string) => Promise<{ active: boolean; balance: bigint }>;
  activeStrategies: (index: bigint) => Promise<string>;
  deposit: (assets: bigint, receiver: string) => Promise<ethers.TransactionResponse>;
  withdraw: (assets: bigint, receiver: string, owner: string) => Promise<ethers.TransactionResponse>;
  asset: () => Promise<string>;
  UNDERLYING: () => Promise<string>;
}

// Update network constants
const AMOY_CHAIN_ID = BigInt(80002);
const AMOY_RPC_URL = 'https://rpc-amoy.polygon.technology';

// Update network configuration
const AMOY_NETWORK_CONFIG = {
  chainId: `0x${AMOY_CHAIN_ID.toString(16)}`,
  chainName: 'Amoy Testnet',
  nativeCurrency: {
    name: 'POL',
    symbol: 'POL',
    decimals: 18,
  },
  rpcUrls: [AMOY_RPC_URL],
  blockExplorerUrls: ['https://amoy.polygonscan.com/'],
};

const YieldAggregatorDashboard = () => {
  const [activeTab, setActiveTab] = useState('vaults');
  const [vaults, setVaults] = useState<Vault[]>([]);
  const [selectedVault, setSelectedVault] = useState<Vault | null>(null);
  const [provider, setProvider] = useState<ethers.BrowserProvider | null>(null);
  const [signer, setSigner] = useState<ethers.JsonRpcSigner | null>(null);
  const [vaultFactoryContract, setVaultFactoryContract] = useState<ethers.Contract | null>(null);
  const [assetAddress, setAssetAddress] = useState('');
  const [vaultName, setVaultName] = useState('');
  const [vaultSymbol, setVaultSymbol] = useState('');
  const [isConnecting, setIsConnecting] = useState(false);
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [userVaultBalance, setUserVaultBalance] = useState('0');
  const [newStrategyAddress, setNewStrategyAddress] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  const VAULT_FACTORY_ADDRESS = '0xC5Bb65728B18E53AD4E5d7f39ca37Bf3BEf48951'; // Replace with your deployed address on Amoy Testnet

  useEffect(() => {
    if (typeof window !== 'undefined' && window.ethereum && !provider) {
      const newProvider = new ethers.JsonRpcProvider(AMOY_RPC_URL);
      setProvider(newProvider);

      // Check initial connection status
      window.ethereum.request({ method: 'eth_accounts' }).then((accounts: string[]) => {
        setIsConnected(accounts.length > 0);
      });

      // Update event listeners
      window.ethereum.on('accountsChanged', (accounts: string[]) => {
        setIsConnected(accounts.length > 0);
        if (accounts.length === 0) {
          // Reset states when disconnected
          setSigner(null);
          setVaultFactoryContract(null);
          setVaults([]);
        } else {
          // Reconnect if new account selected
          connectWallet();
        }
      });

      window.ethereum.on('chainChanged', () => {
        window.location.reload();
      });

      return () => {
        window.ethereum.removeListener('accountsChanged', () => {});
        window.ethereum.removeListener('chainChanged', () => {});
      };
    }
  }, [provider]);

  useEffect(() => {
    if (vaultFactoryContract && signer) {
      loadVaults(vaultFactoryContract);
    }
  }, [signer, vaultFactoryContract]);

  const connectWallet = async () => {
    if (!provider) {
      setError('Please install MetaMask');
      return;
    }

    try {
      setIsConnecting(true);
      setError(null);

      // Check current network
      const network = await provider.getNetwork();
      console.log('Current network:', network);

      // If not on Amoy testnet, prompt to switch
      if (network.chainId !== AMOY_CHAIN_ID) {
        try {
          // Try to switch to Amoy testnet
          await window.ethereum.request({
            method: 'wallet_switchEthereumChain',
            params: [{ chainId: `0x${AMOY_CHAIN_ID.toString(16)}` }],
          });
        } catch (switchError: any) {
          // If the network doesn't exist in MetaMask, add it
          if (switchError.code === 4902) {
            try {
              await window.ethereum.request({
                method: 'wallet_addEthereumChain',
                params: [AMOY_NETWORK_CONFIG],
              });
            } catch (addError) {
              throw new Error('Failed to add Amoy network to MetaMask');
            }
          } else {
            throw new Error('Failed to switch to Amoy network');
          }
        }
      }

      // Request account access
      await provider.send('eth_requestAccounts', []);

      // Get the signer after accounts are available
      const newSigner = await provider.getSigner();
      setSigner(newSigner);

      // Verify the contract exists
      const code = await provider.getCode(VAULT_FACTORY_ADDRESS);
      // console.log('Contract code:', code);

      if (code === '0x' || code === '0x0') {
        throw new Error('No contract deployed at this address. Please verify the network and contract address.');
      }

      // Initialize the VaultFactory contract with signer
      const factoryContract = new ethers.Contract(VAULT_FACTORY_ADDRESS, VaultFactoryABI.abi, newSigner);
      setVaultFactoryContract(factoryContract);

      // Load vaults after contract is initialized
      await loadVaults(factoryContract);
    } catch (error: any) {
      console.error('Error connecting wallet:', error);
      setError(error.message || 'Failed to connect wallet');
    } finally {
      setIsConnecting(false);
    }
  };

  const loadVaults = async (factoryContract: ethers.Contract) => {
    if (!signer) {
      setError('Please connect your wallet first');
      return;
    }

    setIsLoading(true);
    setError(null);
    try {
      console.log('Starting vault loading process...');
      const vaultCount: bigint = await factoryContract.getVaultCount();
      console.log('Vault count:', vaultCount.toString());

      const vaultsArray: Vault[] = [];

      for (let i = 0n; i < vaultCount; i++) {
        try {
          const vaultAddress = await factoryContract.getVault(i);
          console.log(`Vault address at index ${i}: ${vaultAddress}`);

          if (
            vaultAddress &&
            vaultAddress !== '0x0000000000000000000000000000000000000000' &&
            vaultAddress !== ethers.ZeroAddress
          ) {
            const vaultContract = new ethers.Contract(vaultAddress, VaultABI.abi, signer) as VaultContract;
            console.log('Created vault contract instance');

            const name = await vaultContract.name();
            const symbol = await vaultContract.symbol();
            const totalAssets = await vaultContract.totalAssets();
            const decimals = await vaultContract.decimals();
            const strategies = await vaultContract.getStrategiesCount();

            const formattedTotalAssets = ethers.formatUnits(totalAssets, decimals);

            const vault: Vault = {
              address: vaultAddress,
              name,
              symbol,
              totalAssets: formattedTotalAssets,
              apy: 'N/A', // Replace with actual APY if available
              strategies: Number(strategies),
              tvl: formattedTotalAssets, // Replace with actual TVL if different
            };

            console.log('Adding vault:', vault);
            vaultsArray.push(vault);
          }
        } catch (vaultError) {
          console.error(`Error getting vault at index ${i}:`, vaultError);
          // Optionally handle individual vault load errors
        }
      }

      setVaults(vaultsArray);
    } catch (error: any) {
      console.error('Error in loadVaults:', error);
      setError(error.message || 'Failed to load vaults');
    } finally {
      setIsLoading(false);
    }
  };

  const deployVault = async (event: React.FormEvent) => {
    event.preventDefault();
    if (vaultFactoryContract && signer) {
      try {
        const tx = await vaultFactoryContract.deployVault(assetAddress, vaultName, vaultSymbol);
        await tx.wait();
        // Reload the vaults
        await loadVaults(vaultFactoryContract);
        // Reset form
        setAssetAddress('');
        setVaultName('');
        setVaultSymbol('');
        setActiveTab('vaults');
      } catch (error: any) {
        console.error('Error deploying vault:', error);
        alert(`Error deploying vault: ${error.message || error}`);
      }
    } else {
      alert('Please connect your wallet!');
    }
  };

  const loadUserVaultBalance = async (vaultContract: ethers.Contract) => {
    if (signer) {
      try {
        const account = await signer.getAddress();
        const balance = await vaultContract.balanceOf(account);
        const decimals = await vaultContract.decimals();
        setUserVaultBalance(ethers.formatUnits(balance, decimals));
      } catch (error) {
        console.error('Error loading user vault balance:', error);
      }
    }
  };

  useEffect(() => {
    if (selectedVault && signer) {
      const vaultContract = new ethers.Contract(selectedVault.address, VaultABI.abi, signer);
      loadUserVaultBalance(vaultContract);
    }
  }, [selectedVault, signer]);

  const handleDeposit = async () => {
    if (!selectedVault || !signer) return;
    if (!depositAmount || isNaN(Number(depositAmount)) || Number(depositAmount) <= 0) {
      setError('Please enter a valid deposit amount');
      return;
    }

    setIsLoading(true);
    try {
      const vaultContract = new ethers.Contract(selectedVault.address, VaultABI.abi, signer) as VaultContract;
      const assetAddress = await vaultContract.asset();
      const decimals = await vaultContract.decimals();
      const amountInWei = ethers.parseUnits(depositAmount, decimals);

      // Get user address
      const userAddress = await signer.getAddress();

      // Approve the vault to spend user's tokens
      const assetContract = new ethers.Contract(
        assetAddress,
        ['function approve(address spender, uint256 amount) public returns (bool)'],
        signer
      );

      const approveTx = await assetContract.approve(selectedVault.address, amountInWei);
      await approveTx.wait();

      // Deposit assets into the vault
      const depositTx = await vaultContract.deposit(amountInWei, userAddress);
      await depositTx.wait();

      // Reload balances
      setDepositAmount('');
      await loadUserVaultBalance(vaultContract);
    } catch (error: any) {
      setError(error.message || 'Failed to deposit');
    } finally {
      setIsLoading(false);
    }
  };

  const handleWithdraw = async () => {
    if (!selectedVault || !signer) return;
    if (!withdrawAmount || isNaN(Number(withdrawAmount)) || Number(withdrawAmount) <= 0) {
      setError('Please enter a valid withdrawal amount');
      return;
    }

    setIsLoading(true);
    try {
      const vaultContract = new ethers.Contract(selectedVault.address, VaultABI.abi, signer) as VaultContract;
      const decimals = await vaultContract.decimals();
      const amountInWei = ethers.parseUnits(withdrawAmount, decimals);
      const userAddress = await signer.getAddress();

      // Withdraw assets from the vault
      const withdrawTx = await vaultContract.withdraw(amountInWei, userAddress, userAddress);
      await withdrawTx.wait();

      // Reload balances
      setWithdrawAmount('');
      await loadUserVaultBalance(vaultContract);
    } catch (error: any) {
      setError(error.message || 'Failed to withdraw');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAddStrategy = async () => {
    if (selectedVault && signer) {
      try {
        const vaultContract = new ethers.Contract(selectedVault.address, VaultABI.abi, signer);

        const tx = await vaultContract.addStrategy(newStrategyAddress);
        await tx.wait();

        // Update strategies count or reload vault details
        setNewStrategyAddress('');
        // Optionally, reload the vault details
        // await loadVaults(vaultFactoryContract);
      } catch (error: any) {
        console.error('Error adding strategy:', error);
        alert(`Error adding strategy: ${error.message || error}`);
      }
    }
  };

  // Add this function to help debug
  const verifyContract = async () => {
    try {
      const code = await provider?.getCode(VAULT_FACTORY_ADDRESS);
      // console.log('Contract code:', code);
      if (code === '0x') {
        console.error('No contract deployed at this address');
      }
    } catch (error) {
      console.error('Error verifying contract:', error);
    }
  };

  // Call it after connecting
  useEffect(() => {
    if (provider && VAULT_FACTORY_ADDRESS) {
      verifyContract();
    }
  }, [provider]);

  useEffect(() => {
    const verifySetup = async () => {
      if (!provider) return;

      try {
        // Check network connection
        const network = await provider.getNetwork();
        console.log('Current network:', network);

        // Check if contract exists at address
        const code = await provider.getCode(VAULT_FACTORY_ADDRESS);
        // console.log('Contract code:', code);

        if (code === '0x') {
          console.error('No contract found at address:', VAULT_FACTORY_ADDRESS);
          setError('Contract not found at specified address');
          return;
        }

        // Try basic read-only call
        const factoryContract = new ethers.Contract(VAULT_FACTORY_ADDRESS, VaultFactoryABI.abi, provider);

        try {
          const vaultCount = await factoryContract.getVaultCount();
          console.log('Vault count:', vaultCount.toString());
        } catch (callError) {
          console.error('Failed to read vault count:', callError);
          setError('Failed to read from contract. Please verify the contract address and network.');
        }
      } catch (error) {
        console.error('Setup verification failed:', error);
        setError(`Failed to verify contract setup: ${error.message}`);
      }
    };

    verifySetup();
  }, [provider]);

  // Add network status display
  const NetworkStatus = () => {
    const [currentNetwork, setCurrentNetwork] = useState<string>('Not Connected');

    useEffect(() => {
      const updateNetwork = async () => {
        if (provider && isConnected) {
          try {
            const network = await provider.getNetwork();
            setCurrentNetwork(
              network.chainId === AMOY_CHAIN_ID ? 'Connected to Amoy Testnet' : 'Please connect to Amoy Testnet'
            );
          } catch (error) {
            setCurrentNetwork('Not Connected');
          }
        } else {
          setCurrentNetwork('Not Connected');
        }
      };

      updateNetwork();

      if (window.ethereum) {
        window.ethereum.on('chainChanged', updateNetwork);
        window.ethereum.on('accountsChanged', updateNetwork);
        return () => {
          window.ethereum.removeListener('chainChanged', updateNetwork);
          window.ethereum.removeListener('accountsChanged', updateNetwork);
        };
      }
    }, [provider, isConnected]);

    return <div className="text-sm text-gray-600">{currentNetwork}</div>;
  };

  // Add this useEffect to debug contract initialization
  useEffect(() => {
    const debugContract = async () => {
      if (vaultFactoryContract && signer) {
        console.log('Factory contract initialized:', vaultFactoryContract.target);
        try {
          const count = await vaultFactoryContract.getVaultCount();
          console.log('Vault count from debug:', count.toString());
        } catch (error) {
          console.error('Error in debug contract call:', error);
        }
      }
    };

    debugContract();
  }, [vaultFactoryContract, signer]);

  useEffect(() => {
    if (!provider) {
      const newProvider = new ethers.JsonRpcProvider(AMOY_RPC_URL);
      setProvider(newProvider);
    }
  }, [provider]);

  return (
    <div className="container mx-auto p-4">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Yield Aggregator Dashboard</h1>
        <div className="flex items-center gap-4">
          <NetworkStatus />
          <Button onClick={connectWallet} disabled={isConnecting} className="flex items-center gap-2">
            {isConnecting ? <Loader2 className="h-4 w-4 animate-spin" /> : <WalletIcon className="h-4 w-4" />}
            {isConnected ? 'Connected' : 'Connect Wallet'}
          </Button>
        </div>
      </div>

      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Navigation */}
      <div className="flex gap-4 mb-6">
        <Button variant={activeTab === 'vaults' ? 'default' : 'outline'} onClick={() => setActiveTab('vaults')}>
          Vaults
        </Button>
        <Button variant={activeTab === 'create' ? 'default' : 'outline'} onClick={() => setActiveTab('create')}>
          Create Vault
        </Button>
      </div>

      {isLoading ? (
        <div className="flex justify-center items-center min-h-[200px]">
          <Loader2 className="h-8 w-8 animate-spin" />
        </div>
      ) : activeTab === 'vaults' ? (
        /* Vaults List */
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {vaults.map((vault) => (
            <Card key={vault.address}>
              <CardHeader>
                <CardTitle>{vault.name}</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-2">
                  <p>Symbol: {vault.symbol}</p>
                  <p>Total Assets: {vault.totalAssets}</p>
                  <p>Strategies: {vault.strategies}</p>
                  {/* Additional details */}
                  <Button variant="outline" className="mt-2" onClick={() => setSelectedVault(vault)}>
                    Manage Vault
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}

          {/* Vault Details Section */}
          {selectedVault && (
            <Card className="col-span-1 md:col-span-2">
              <CardHeader>
                <CardTitle>{selectedVault.name}</CardTitle>
              </CardHeader>
              <CardContent>
                {/* User Balance and Actions */}
                <div className="space-y-4">
                  <h3 className="text-lg font-medium">
                    Your Balance: {userVaultBalance} {selectedVault.symbol}
                  </h3>
                  <div className="flex gap-4">
                    <Input
                      placeholder="Amount to deposit"
                      value={depositAmount}
                      onChange={(e) => setDepositAmount(e.target.value)}
                    />
                    <Button
                      className="flex items-center gap-2"
                      onClick={handleDeposit}
                      disabled={isLoading || !depositAmount || !selectedVault}>
                      {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <PlusCircle className="h-4 w-4" />}
                      Deposit
                    </Button>
                  </div>
                  <div className="flex gap-4">
                    <Input
                      placeholder="Amount to withdraw"
                      value={withdrawAmount}
                      onChange={(e) => setWithdrawAmount(e.target.value)}
                    />
                    <Button
                      variant="outline"
                      className="flex items-center gap-2"
                      onClick={handleWithdraw}
                      disabled={isLoading || !withdrawAmount || !selectedVault}>
                      {isLoading ? <Loader2 className="h-4 w-4 animate-spin" /> : <MinusCircle className="h-4 w-4" />}
                      Withdraw
                    </Button>
                  </div>
                </div>

                {/* Strategy Management (for vault owner) */}
                <div className="space-y-4 mt-6">
                  <h3 className="text-lg font-medium">Strategy Management</h3>
                  <Alert>
                    <AlertDescription>Active Strategies: {selectedVault.strategies}</AlertDescription>
                  </Alert>
                  <div className="flex gap-4">
                    <Input
                      placeholder="Strategy Contract Address"
                      value={newStrategyAddress}
                      onChange={(e) => setNewStrategyAddress(e.target.value)}
                    />
                    <Button className="flex items-center gap-2" onClick={handleAddStrategy}>
                      <PlusCircle className="h-4 w-4" />
                      Add Strategy
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          )}
        </div>
      ) : (
        /* Create Vault Form */
        <Card>
          <CardHeader>
            <CardTitle>Create New Vault</CardTitle>
          </CardHeader>
          <CardContent>
            <form className="space-y-4" onSubmit={deployVault}>
              <div>
                <label className="block text-sm font-medium mb-1">Asset Address</label>
                <Input
                  placeholder="0x..."
                  value={assetAddress}
                  onChange={(e) => setAssetAddress(e.target.value)}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Vault Name</label>
                <Input
                  placeholder="USDC Yield Vault"
                  value={vaultName}
                  onChange={(e) => setVaultName(e.target.value)}
                  required
                />
              </div>
              <div>
                <label className="block text-sm font-medium mb-1">Vault Symbol</label>
                <Input
                  placeholder="vUSDC"
                  value={vaultSymbol}
                  onChange={(e) => setVaultSymbol(e.target.value)}
                  required
                />
              </div>
              <Button className="w-full" type="submit">
                Deploy Vault
              </Button>
            </form>
          </CardContent>
        </Card>
      )}
    </div>
  );
};

export default YieldAggregatorDashboard;
