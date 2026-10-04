import { createPublicClient, http, parseEther, formatEther } from 'viem';
import { monadTestnet } from 'viem/chains';

export class MeshSDK {
  private publicClient: ReturnType<typeof createPublicClient>;

  constructor(config: { rpcUrl?: string }) {
    this.publicClient = createPublicClient({
      chain: monadTestnet,
      transport: http(config.rpcUrl || 'https://testnet-rpc.monad.xyz'),
    });
  }

  async getBalance(address: `0x${string}`) {
    const balance = await this.publicClient.getBalance({ address });
    return formatEther(balance);
  }

  async getBlockNumber() {
    return this.publicClient.getBlockNumber();
  }
}
