'use client';

import { Alert, AlertDescription } from '@/components/ui/alert';
import { Button } from '@/components/ui/button';
import { Loader2, WalletIcon } from 'lucide-react';
import React, { useEffect, useState } from 'react';

// Import Wagmi and AppKit hooks
import { useAppKit } from '@reown/appkit/react';
import {
  useAccount,
  useChainId,
  useReadContract,
  useReadContracts,
  useWaitForTransactionReceipt,
  useWriteContract,
} from 'wagmi';
// Import the ABIs
import VaultABI from '@/abis/Vault.json';
import VaultFactoryABI from '@/abis/VaultFactory.json';
import { Address } from 'viem';
import CreateVaultForm from './CreateVaultForm';
import { VaultList } from './VaultList';

interface Vault {
  address: string;
  name: string;
  symbol: string;
  totalAssets: string;
  apy: string;
  strategies: number;
  tvl: string;
}

const AMOY_CHAIN_ID = 80002;
const VAULT_FACTORY_ADDRESS = '0xC5Bb65728B18E53AD4E5d7f39ca37Bf3BEf48951';

const YieldAggregatorDashboard = () => {
  const [activeTab, setActiveTab] = useState('vaults');
  // const [vaults, setVaults] = useState<Vault[]>([]);
  const [selectedVault, setSelectedVault] = useState<Vault | null>(null);
  const [depositAmount, setDepositAmount] = useState('');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [userVaultBalance, setUserVaultBalance] = useState('0');
  const [newStrategyAddress, setNewStrategyAddress] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [assetAddress, setAssetAddress] = useState('');
  const [vaultName, setVaultName] = useState('');
  const [vaultSymbol, setVaultSymbol] = useState('');

  // Updated Wagmi hooks
  const { address, isConnected } = useAccount();
  const chainId = useChainId();
  const { open } = useAppKit();

  // Read vault count
  const { data, isLoading: isReadLoading } = useReadContracts({
    contracts: [
      {
        address: VAULT_FACTORY_ADDRESS,
        abi: VaultFactoryABI.abi,
        functionName: 'getVaultCount',
      },
      {
        address: VAULT_FACTORY_ADDRESS,
        abi: VaultFactoryABI.abi,
        functionName: 'vaults',
        args: [0],
      },
    ],
  });
  const [vaultCount, vaults] = data || [];
  console.log('vaultCount', vaultCount);
  console.log('vaults', vaults);

  const { data: vault } = useReadContract({
    address: VAULT_FACTORY_ADDRESS,
    abi: VaultFactoryABI.abi,
    functionName: 'getVault',
    args: [Array.isArray(vaults?.result) ? vaults?.result : [vaults?.result]],
  });

  console.log('vault', vault);

  // Deploy vault contract write
  const { data: deployHash, writeContract: deployVault } = useWriteContract();

  const { isLoading: isDeployLoading, isSuccess: isDeploySuccess } = useWaitForTransactionReceipt({
    hash: deployHash,
  });

  // Add this with other contract writes
  const { writeContract: addStrategy } = useWriteContract();

  // const { data: vaultAddresses } = useReadContract({
  //   address: VAULT_FACTORY_ADDRESS,
  //   abi: VaultFactoryABI.abi,
  //   functionName: 'getVaults', // Assuming there's a function to get all vaults
  // });

  // console.log('vaultAddresses', vaultAddresses);

  useEffect(() => {
    if (isConnected) {
      if (chainId !== AMOY_CHAIN_ID) {
        // Use AppKit's network switching
        open({ view: 'Networks' });
      } else {
        // loadVaults();
        // console.log('vaultAddresses', vaultAddresses);
      }
    }
  }, [isConnected, chainId]);

  // const loadVaults = async () => {
  //   if (!isConnected) {
  //     setError('Please connect your wallet first');
  //     return;
  //   }

  //   setIsLoading(true);
  //   setError(null);
  //   try {
  //     const vaultArray: Vault[] = [];
  //     const count = Number(vaultCount || 0);
  //     console.log('Total vault count from contract:', count);

  //     for (let i = 0; i < count; i++) {
  //       try {
  //         const vaultAddress = await readContract(config, {
  //           address: VAULT_FACTORY_ADDRESS,
  //           abi: VaultFactoryABI.abi,
  //           functionName: 'getVault',
  //           args: [i],
  //         });

  //         if (vaultAddress && vaultAddress !== '0x0000000000000000000000000000000000000000') {
  //           const [name, symbol, totalAssets, strategies] = await Promise.all([
  //             readContract(config, {
  //               address: vaultAddress as Address,
  //               abi: VaultABI.abi,
  //               functionName: 'name',
  //               chainId: AMOY_CHAIN_ID,
  //             }),
  //             readContract(config, {
  //               address: vaultAddress as Address,
  //               abi: VaultABI.abi,
  //               functionName: 'symbol',
  //               chainId: AMOY_CHAIN_ID,
  //             }),
  //             readContract(config, {
  //               address: vaultAddress as Address,
  //               abi: VaultABI.abi,
  //               functionName: 'totalAssets',
  //               chainId: AMOY_CHAIN_ID,
  //             }),
  //             readContract(config, {
  //               address: vaultAddress as Address,
  //               abi: VaultABI.abi,
  //               functionName: 'decimals',
  //               chainId: AMOY_CHAIN_ID,
  //             }),
  //             readContract(config, {
  //               address: vaultAddress as Address,
  //               abi: VaultABI.abi,
  //               functionName: 'getStrategiesCount',
  //               chainId: AMOY_CHAIN_ID,
  //             }),
  //           ]);

  //           const vault: Vault = {
  //             address: vaultAddress,
  //             name,
  //             symbol,
  //             totalAssets: totalAssets?.toString() || '0',
  //             apy: 'N/A',
  //             strategies: Number(strategies) || 0,
  //             tvl: totalAssets?.toString() || '0',
  //           };

  //           vaultArray.push(vault);
  //         }
  //       } catch (vaultError) {
  //         console.error(`Error getting vault at index ${i}:`, vaultError);
  //       }
  //     }

  //     console.log('Successfully loaded vaults:', vaultArray.length);
  //     console.log('Vault details:', vaultArray);

  //     setVaults(vaultArray);
  //   } catch (error: any) {
  //     console.error('Error in loadVaults:', error);
  //     setError(error.message || 'Failed to load vaults');
  //   } finally {
  //     setIsLoading(false);
  //   }
  // };

  const handleDeployVault = async (event: React.FormEvent) => {
    event.preventDefault();

    console.log('handleDeployVault');
    if (!isConnected) {
      setError('Please connect your wallet!');
      return;
    }

    try {
      deployVault({
        address: VAULT_FACTORY_ADDRESS,
        abi: VaultFactoryABI.abi,
        functionName: 'deployVault',
        args: [assetAddress, vaultName, vaultSymbol],
      });
    } catch (error: any) {
      console.error('Error deploying vault:', error);
      setError(error.message || 'Failed to deploy vault');
    }
  };

  useEffect(() => {
    if (isDeploySuccess) {
      // loadVaults();
      setAssetAddress('');
      setVaultName('');
      setVaultSymbol('');
      setActiveTab('vaults');
    }
  }, [isDeploySuccess]);

  // Handle deposit
  const { writeContract: deposit, data: depositData } = useWriteContract();

  const handleDeposit = async () => {
    if (!selectedVault || !depositAmount) return;

    try {
      deposit({
        address: selectedVault.address as Address,
        abi: VaultABI.abi,
        functionName: 'deposit',
        args: [depositAmount],
      });
    } catch (error: any) {
      console.error('Error during deposit:', error);
      setError(error.message || 'Failed to deposit');
    }
  };

  // Handle withdraw
  const { writeContract: withdraw } = useWriteContract();

  const handleWithdraw = async () => {
    if (!selectedVault || !withdrawAmount) return;

    try {
      withdraw({
        address: selectedVault.address as Address,
        abi: VaultABI.abi,
        functionName: 'withdraw',
        args: [withdrawAmount],
      });
    } catch (error: any) {
      console.error('Error during withdrawal:', error);
      setError(error.message || 'Failed to withdraw');
    }
  };

  // Get user's vault balance
  const { data: vaultBalance } = useReadContract({
    address: selectedVault?.address as Address,
    abi: VaultABI.abi,
    functionName: 'balanceOf',
    args: [address],
  });

  useEffect(() => {
    if (vaultBalance) {
      setUserVaultBalance(vaultBalance.toString());
    }
  }, [vaultBalance]);

  const handleAddStrategy = async () => {
    if (!selectedVault || !newStrategyAddress || !isConnected) return;

    try {
      addStrategy({
        address: selectedVault.address as Address,
        abi: VaultABI.abi,
        functionName: 'addStrategy',
        args: [newStrategyAddress],
      });

      // Clear the input
      setNewStrategyAddress('');

      // Optionally reload vaults after strategy is added
      // await loadVaults();
    } catch (error: any) {
      console.error('Error adding strategy:', error);
      setError(error.message || 'Failed to add strategy');
    }
  };

  const connectWallet = () => {
    open();
  };

  // Add network status display
  const NetworkStatus = () => {
    const [mounted, setMounted] = useState(false);

    useEffect(() => {
      setMounted(true);
    }, []);

    // Don't render anything until client-side
    if (!mounted) return null;

    const currentNetwork = chainId === AMOY_CHAIN_ID ? 'Connected to Amoy Testnet' : 'Please connect to Amoy Testnet';

    return <div className="text-sm text-gray-600">{currentNetwork}</div>;
  };

  // Add mounted state for client-side rendering
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    setMounted(true);
  }, []);

  // Modify the wallet button render logic
  const renderWalletButton = () => {
    if (!mounted)
      return (
        <Button className="flex items-center gap-2">
          <WalletIcon className="h-4 w-4" />
          Connect Wallet
        </Button>
      );

    return (
      <Button onClick={connectWallet} className="flex items-center gap-2">
        <WalletIcon className="h-4 w-4" />
        {isConnected ? 'Connected' : 'Connect Wallet'}
      </Button>
    );
  };

  return (
    <div className="container mx-auto p-4">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold">Yield Aggregator Dashboard</h1>
        <div className="flex items-center gap-4">
          <NetworkStatus />
          {renderWalletButton()}
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
        // <VaultList vaultsCount={vaultCount} vaults={vaults} isReadLoading={isReadLoading} />
        <div>Vaults List</div>
      ) : (
        /* Create Vault Form */
        <CreateVaultForm
          handleDeployVault={handleDeployVault}
          assetAddress={assetAddress}
          setAssetAddress={setAssetAddress}
          vaultName={vaultName}
          setVaultName={setVaultName}
          vaultSymbol={vaultSymbol}
          setVaultSymbol={setVaultSymbol}
        />
      )}
    </div>
  );
};

export default YieldAggregatorDashboard;
