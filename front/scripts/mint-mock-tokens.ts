import { SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64 } from "@mysten/sui/utils";
import "dotenv/config";
import deployedAddresses from "../src/deployed_addresses.json";

const PACKAGE_ID = deployedAddresses.PACKAGE_ID;
const USDT_TREASURY_CAP = (
  deployedAddresses as unknown as { MOCK_USDT_TREASURY: string }
).MOCK_USDT_TREASURY;
const USDC_TREASURY_CAP = (
  deployedAddresses as unknown as { MOCK_USDC_TREASURY: string }
).MOCK_USDC_TREASURY;

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const NETWORK_URL = process.env.VITE_NETWORK_URL;

if (!PRIVATE_KEY || !NETWORK_URL) {
  console.error("❌ PRIVATE_KEY ou VITE_NETWORK_URL non définis dans .env");
  process.exit(1);
}

if (!USDT_TREASURY_CAP || !USDC_TREASURY_CAP) {
  console.error(
    "❌ Treasury Caps manquants. Assurez-vous d'avoir déployé les contrats mock.",
  );
  console.error("Exécutez: npm run deploy");
  process.exit(1);
}

const keypair = Ed25519Keypair.fromSecretKey(fromBase64(PRIVATE_KEY).slice(1));
const client = new SuiClient({ url: NETWORK_URL });

/**
 * Mint des tokens mock USDT
 */
export async function mintMockUSDT(
  keypair: Ed25519Keypair,
  amount: number, // Montant en unités entières (sera multiplié par 10^6)
  recipient: string,
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::mock_usdt::mint`,
    arguments: [
      tx.object(USDT_TREASURY_CAP),
      tx.pure.u64(BigInt(amount * 1_000_000)), // 6 décimales
      tx.pure.address(recipient),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
    options: {
      showEffects: true,
    },
  });

  console.log(`✅ Minted ${amount} MOCK_USDT. Transaction: ${result.digest}`);
  return result;
}

/**
 * Mint des tokens mock USDC
 */
export async function mintMockUSDC(
  keypair: Ed25519Keypair,
  amount: number, // Montant en unités entières (sera multiplié par 10^6)
  recipient: string,
) {
  const tx = new Transaction();

  tx.moveCall({
    target: `${PACKAGE_ID}::mock_usdc::mint`,
    arguments: [
      tx.object(USDC_TREASURY_CAP),
      tx.pure.u64(BigInt(amount * 1_000_000)), // 6 décimales
      tx.pure.address(recipient),
    ],
  });

  const result = await client.signAndExecuteTransaction({
    signer: keypair,
    transaction: tx,
    options: {
      showEffects: true,
    },
  });

  console.log(`✅ Minted ${amount} MOCK_USDC. Transaction: ${result.digest}`);
  return result;
}

/**
 * Obtenir les adresses des types de coins mock
 */
export function getMockCoinTypes() {
  return {
    MOCK_USDT: `${PACKAGE_ID}::mock_usdt::MOCK_USDT`,
    MOCK_USDC: `${PACKAGE_ID}::mock_usdc::MOCK_USDC`,
  };
}

/**
 * Fonction utilitaire pour mint des tokens de test (en une seule transaction)
 */
export async function mintTestTokens(
  keypair: Ed25519Keypair,
  recipient: string,
  usdtAmount = 10000, // 10,000 USDT par défaut
  usdcAmount = 10000, // 10,000 USDC par défaut
) {
  console.log(`🪙 Minting test tokens for ${recipient}...`);

  try {
    // Créer une seule transaction pour les deux mints
    const tx = new Transaction();

    // Mint MOCK_USDT
    tx.moveCall({
      target: `${PACKAGE_ID}::mock_usdt::mint`,
      arguments: [
        tx.object(USDT_TREASURY_CAP),
        tx.pure.u64(BigInt(usdtAmount * 1_000_000)), // 6 décimales
        tx.pure.address(recipient),
      ],
    });

    // Mint MOCK_USDC dans la même transaction
    tx.moveCall({
      target: `${PACKAGE_ID}::mock_usdc::mint`,
      arguments: [
        tx.object(USDC_TREASURY_CAP),
        tx.pure.u64(BigInt(usdcAmount * 1_000_000)), // 6 décimales
        tx.pure.address(recipient),
      ],
    });

    const result = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: tx,
      options: {
        showEffects: true,
      },
    });

    console.log(
      `✅ Minted ${usdtAmount} MOCK_USDT and ${usdcAmount} MOCK_USDC. Transaction: ${result.digest}`,
    );
    console.log(`✅ Successfully minted test tokens!`);
    return result;
  } catch (error) {
    console.error(`❌ Error minting tokens:`, error);
    throw error;
  }
}

// Script principal
async function main() {
  const address = keypair.getPublicKey().toSuiAddress();

  console.log(`🚀 Minting tokens pour l'adresse: ${address}`);
  console.log(`📦 Package ID: ${PACKAGE_ID}`);

  // Mint 10,000 USDT et 10,000 USDC par défaut
  await mintTestTokens(keypair, address, 10000, 10000);
}

// Exécuter le script s'il est appelé directement
if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch(console.error);
}
