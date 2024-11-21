'use client';

import { Button } from '@/components/ui/button';
import { useAppKit } from '@reown/appkit/react';
import { WalletIcon } from 'lucide-react';

export default function ConnectButton() {
  const { open } = useAppKit();

  return (
    <>
      <Button onClick={() => open()} className="flex items-center gap-2">
        <WalletIcon className="h-4 w-4" />
        Connect Wallet
      </Button>
      {/* <Button onClick={() => open()}>Open Connect Modal</Button> */}
      {/* <Button onClick={() => open({ view: 'Networks' })}>Open Network Modal</Button> */}
    </>
  );
}
