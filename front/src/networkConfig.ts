import { createNetworkConfig } from "@mysten/dapp-kit";
import { getFullnodeUrl } from "@mysten/sui/client";

const { networkConfig, useNetworkVariable, useNetworkVariables } =
  createNetworkConfig({
    localnet: {
      url: getFullnodeUrl("localnet"),
    },
    devnet: {
      url: getFullnodeUrl("devnet"),
    },
    testnet: {
      url: getFullnodeUrl("testnet"),
    },
    mainnet: {
      url: getFullnodeUrl("mainnet"),
    },
  });

export { networkConfig, useNetworkVariable, useNetworkVariables };
