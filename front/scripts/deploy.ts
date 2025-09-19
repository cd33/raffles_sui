import { bcs } from "@mysten/sui/bcs";
import { SuiClient, SuiObjectChange } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromBase64, SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import { execSync } from "child_process";
import "dotenv/config";
import { writeFileSync } from "fs";
import path, { dirname } from "path";
import { fileURLToPath } from "url";

const find_one_by_type = (changes: SuiObjectChange[], type: string) => {
  const object_change = changes.find(
    (change) => change.type == "created" && change.objectType == type,
  );
  if (object_change?.type == "created") {
    return object_change.objectId;
  }
};

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const NETWORK_URL = process.env.VITE_NETWORK_URL;
if (!PRIVATE_KEY || !NETWORK_URL) {
  console.log("PRIVATE_KEY or NETWORK_URL is not set");
  process.exit(1);
}

const keypair = Ed25519Keypair.fromSecretKey(fromBase64(PRIVATE_KEY).slice(1));
const path_to_contracts = path.join(
  dirname(fileURLToPath(import.meta.url)),
  "../../contracts",
);

const client = new SuiClient({ url: NETWORK_URL });

console.log("Building contracts...");
const { modules, dependencies } = JSON.parse(
  execSync(
    `sui move build --dump-bytecode-as-base64 --path ${path_to_contracts}`,
    { encoding: "utf-8" },
  ),
);

console.log("Deploying from address:", keypair.toSuiAddress());
const deploy_tx = new Transaction();
const [upgrade_cap] = deploy_tx.publish({
  modules,
  dependencies,
});

deploy_tx.transferObjects([upgrade_cap], keypair.toSuiAddress());
const { objectChanges, balanceChanges } =
  await client.signAndExecuteTransaction({
    transaction: deploy_tx,
    signer: keypair,
    options: {
      showBalanceChanges: true,
      showEffects: true,
      showEvents: true,
      showInput: false,
      showObjectChanges: true,
      showRawInput: false,
    },
  });

if (balanceChanges) {
  console.log(
    "Cost to deploy:",
    Math.abs(parseInt(balanceChanges[0].amount)) / 1_000_000_000,
    "SUI",
  );
}

if (!objectChanges) {
  console.log("Error: RPC did not return objectChanges");
  process.exit(1);
}
const published_event = objectChanges.find(
  (obj: SuiObjectChange) => obj.type == "published",
);
if (published_event?.type != "published") {
  process.exit(1);
}

const package_id = published_event.packageId;
const admin_cap_type = `${package_id}::raffles::AdminCap`;

const admin_cap_id = find_one_by_type(objectChanges, admin_cap_type);
if (!admin_cap_id) {
  console.log("Error: Could not find AdminCap creation in results of publish");
  process.exit(1);
}

let deployed_addresses = {
  PACKAGE_ID: package_id,
  ADMIN_CAP: admin_cap_id,
};
console.log("deployed_addresses", deployed_addresses);

// Attendre quelques blocks
const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));
await wait(2500);

// Créer une raffle et stocker l'adresse dans deployed_addresses
const raffle_tx = new Transaction();
const [reward] = raffle_tx.splitCoins(raffle_tx.gas, [
  10_000_000_000n, // 10 SUI
]);
const end_date = Date.now() + 1000 * 60 * 60 * 24 * 7;
const min_tickets = 6;
const max_tickets = 10;
const ticket_price = 2_000_000_000; // 2 SUI

raffle_tx.moveCall({
  target: `${package_id}::raffles::create_raffle`,
  typeArguments: ["0x2::sui::SUI", "0x2::sui::SUI"],
  arguments: [
    raffle_tx.sharedObjectRef({
      objectId: SUI_CLOCK_OBJECT_ID,
      initialSharedVersion: 1,
      mutable: false,
    }),
    reward,
    raffle_tx.pure(bcs.u64().serialize(BigInt(ticket_price)).toBytes()),
    raffle_tx.pure(bcs.u64().serialize(BigInt(end_date)).toBytes()),
    raffle_tx.pure(bcs.u64().serialize(BigInt(min_tickets)).toBytes()),
    raffle_tx.pure(bcs.u64().serialize(BigInt(max_tickets)).toBytes()),
  ],
});

const txData = await client.signAndExecuteTransaction({
  transaction: raffle_tx,
  signer: keypair,
  options: {
    showBalanceChanges: true,
    showEffects: true,
    showEvents: true,
    showInput: false,
    showObjectChanges: true,
    showRawInput: false,
  },
});

if (!txData.objectChanges) {
  console.log("Error: RPC did not return objectChanges");
  process.exit(1);
}

const raffle_id = find_one_by_type(
  txData.objectChanges,
  `${package_id}::raffles::Raffle<0x2::sui::SUI, 0x2::sui::SUI>`,
);

deployed_addresses = Object.assign(deployed_addresses, {
  RAFFLE: raffle_id,
});
console.log("deployed_addresses", deployed_addresses);

console.log("Writing addresses to json...");
const path_to_address_file = path.join(
  dirname(fileURLToPath(import.meta.url)),
  "../src/deployed_addresses.json",
);
writeFileSync(
  path_to_address_file,
  JSON.stringify(deployed_addresses, null, 4),
);
console.log("DONE");
