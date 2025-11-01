import type { SuiClient } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { PACKAGE_ID, WHITELIST_REGISTRY } from "../deployed_addresses.json";

export const SUI_TYPE_MOVE =
  "0000000000000000000000000000000000000000000000000000000000000002::sui::SUI";

// Types
export type WhitelistRegistry = {
  id: { id: string };
  admin: string;
  whitelisted_coins: string[];
  whitelisted_nfts: string[];
};

// === Fonctions de lecture ===

/**
 * Récupère les informations du registre de whitelist
 */
const getWhitelistRegistry = async (
  suiClient: SuiClient,
): Promise<WhitelistRegistry | null> => {
  try {
    const res = await suiClient.getObject({
      id: WHITELIST_REGISTRY,
      options: {
        showContent: true,
      },
    });

    if (!res.data?.content || res.data.content.dataType !== "moveObject") {
      return null;
    }

    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const fields = (res.data.content as any).fields as WhitelistRegistry;
    return fields;
  } catch (error) {
    console.error("Error fetching whitelist registry:", error);
    return null;
  }
};

/**
 * Vérifie si une adresse est l'admin
 */
export const isAdmin = async (
  suiClient: SuiClient,
  userAddress: string,
): Promise<boolean> => {
  const registry = await getWhitelistRegistry(suiClient);
  return registry?.admin === userAddress;
};

/**
 * Récupère la liste des coins whitelistés
 */
export const getWhitelistedCoins = async (
  suiClient: SuiClient,
): Promise<string[]> => {
  const registry = await getWhitelistRegistry(suiClient);
  return registry?.whitelisted_coins || [];
};

/**
 * Récupère la liste des NFTs whitelistés
 */
export const getWhitelistedNFTs = async (
  suiClient: SuiClient,
): Promise<string[]> => {
  const registry = await getWhitelistRegistry(suiClient);
  return registry?.whitelisted_nfts || [];
};

// === Fonctions d'administration ===

/**
 * Récupère l'AdminCap de l'utilisateur
 */
export const getAdminCap = async (
  suiClient: SuiClient,
  userAddress: string,
): Promise<string | null> => {
  try {
    const objects = await suiClient.getOwnedObjects({
      owner: userAddress,
      filter: {
        StructType: `${PACKAGE_ID}::raffles::AdminCap`,
      },
      options: {
        showContent: true,
      },
    });

    if (objects.data.length === 0) {
      return null;
    }

    return objects.data[0].data?.objectId || null;
  } catch (error) {
    console.error("Error fetching AdminCap:", error);
    return null;
  }
};

/**
 * Ajoute un coin à la whitelist
 */
export const addCoinToWhitelist = (
  adminCapId: string,
  coinType: string,
): Transaction => {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::add_coin_to_whitelist`,
    arguments: [
      tx.object(adminCapId),
      tx.object(WHITELIST_REGISTRY),
      tx.pure.string(coinType),
    ],
  });

  return tx;
};

/**
 * Retire un coin de la whitelist
 */
export const removeCoinFromWhitelist = (
  adminCapId: string,
  coinType: string,
): Transaction => {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::remove_coin_from_whitelist`,
    arguments: [
      tx.object(adminCapId),
      tx.object(WHITELIST_REGISTRY),
      tx.pure.string(coinType),
    ],
  });

  return tx;
};

/**
 * Ajoute un NFT à la whitelist
 */
export const addNFTToWhitelist = (
  adminCapId: string,
  nftType: string,
): Transaction => {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::add_nft_to_whitelist`,
    arguments: [
      tx.object(adminCapId),
      tx.object(WHITELIST_REGISTRY),
      tx.pure.string(nftType),
    ],
  });

  return tx;
};

/**
 * Retire un NFT de la whitelist
 */
export const removeNFTFromWhitelist = (
  adminCapId: string,
  nftType: string,
): Transaction => {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::remove_nft_from_whitelist`,
    arguments: [
      tx.object(adminCapId),
      tx.object(WHITELIST_REGISTRY),
      tx.pure.string(nftType),
    ],
  });

  return tx;
};

/**
 * Formate un type pour l'affichage (raccourcit l'adresse)
 */
export const formatTypeForDisplay = (type: string): string => {
  const parts = type.split("::");
  if (parts.length < 2) return type;

  const address = parts[0];
  const shortAddress =
    address.length > 10
      ? `${address.slice(0, 6)}...${address.slice(-4)}`
      : address;

  return `${shortAddress}::${parts.slice(1).join("::")}`;
};
