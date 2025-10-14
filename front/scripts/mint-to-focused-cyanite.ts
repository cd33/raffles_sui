import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { fromBase64 } from "@mysten/sui/utils";
import "dotenv/config";
import { mintTestTokens } from "./mint-mock-tokens";

// Informations de votre nouvelle adresse focused-cyanite
const FOCUSED_CYANITE_ADDRESS =
  "0x7097cf9a9a572cb87a74c2c0f114d61792a17d6bd7e8eafa2796b1c49e32b741";

// Récupérer la clé privée de l'adresse qui a les treasury caps
const TREASURY_PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!TREASURY_PRIVATE_KEY) {
  console.error("❌ PRIVATE_KEY non définie dans .env");
  process.exit(1);
}

async function main() {
  console.log(`🎯 Minting mock tokens vers focused-cyanite...`);
  console.log(`📍 Adresse cible: ${FOCUSED_CYANITE_ADDRESS}`);

  // Utiliser la clé privée qui a accès aux treasury caps pour mint
  const treasuryKeypair = Ed25519Keypair.fromSecretKey(
    fromBase64(TREASURY_PRIVATE_KEY!).slice(1),
  );

  try {
    // Mint 50,000 USDT et 50,000 USDC pour les tests
    await mintTestTokens(
      treasuryKeypair, // Keypair avec les treasury caps
      FOCUSED_CYANITE_ADDRESS, // Adresse de destination
      50000, // 50,000 USDT
      50000, // 50,000 USDC
    );

    console.log(`✅ Tokens mintés avec succès pour focused-cyanite!`);
    console.log(`📝 Pour vérifier les balances:`);
    console.log(`   sui client balance --address ${FOCUSED_CYANITE_ADDRESS}`);
  } catch (error) {
    console.error("❌ Erreur lors du mint:", error);
  }
}

// Exécuter le script
main().catch(console.error);
