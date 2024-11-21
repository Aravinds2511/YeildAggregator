'use client';

import VaultFactoryABI from '@/abis/VaultFactory.json';
import { FC } from 'react';
import { useReadContract } from 'wagmi';

const VaultFactoryAbi = VaultFactoryABI.abi;
const VAULT_FACTORY_ADDRESS = '0xYourVaultFactoryContractAddress';

const ContractInteraction: FC = () => {
  const { data, isError, isLoading } = useReadContract({
    abi: VaultFactoryAbi,
    address: VAULT_FACTORY_ADDRESS,
    functionName: 'getVaultCount',
  });

  console.log(data);

  //   get vault
  const {
    data: vaultData,
    isError: vaultIsError,
    isLoading: vaultIsLoading,
  } = useReadContract({
    abi: VaultFactoryAbi,
    address: VAULT_FACTORY_ADDRESS,
    functionName: 'getVault',
    args: [data],
  });

  if (vaultIsLoading) return <div>Loading...</div>;
  if (vaultIsError) return <div>Error fetching vault.</div>;

  return <div>Vault: {vaultData?.toString()}</div>;
};

export default ContractInteraction;
