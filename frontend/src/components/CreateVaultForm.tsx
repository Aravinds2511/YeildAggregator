import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Input } from './ui/input';

const CreateVaultForm = ({
  handleDeployVault,
  assetAddress,
  setAssetAddress,
  vaultName,
  setVaultName,
  vaultSymbol,
  setVaultSymbol,
}: {
  handleDeployVault: (e: React.FormEvent<HTMLFormElement>) => void;
  assetAddress: string;
  setAssetAddress: (value: string) => void;
  vaultName: string;
  setVaultName: (value: string) => void;
  vaultSymbol: string;
  setVaultSymbol: (value: string) => void;
}) => {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Create New Vault</CardTitle>
      </CardHeader>
      <CardContent>
        <form className="space-y-4" onSubmit={handleDeployVault}>
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
            <Input placeholder="vUSDC" value={vaultSymbol} onChange={(e) => setVaultSymbol(e.target.value)} required />
          </div>
          <Button className="w-full" type="submit">
            Deploy Vault
          </Button>
        </form>
      </CardContent>
    </Card>
  );
};

export default CreateVaultForm;
