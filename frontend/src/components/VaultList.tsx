import { Loader2, MinusCircle, PlusCircle } from 'lucide-react';
import { Alert, AlertDescription } from './ui/alert';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Input } from './ui/input';

export const VaultList = ({
  vaultsCount,
  vaults,
  isReadLoading,
  setSelectedVault,
}: {
  vaultsCount: number;
  vaults: [];
  isReadLoading: boolean;
  setSelectedVault: (vault: Vault) => void;
}) => {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
      {!isReadLoading &&
        vaults?.map((vault) => (
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
  );
};
