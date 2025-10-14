import type { SuiClient } from "@mysten/sui/client";
import { PaginatedEvents } from "@mysten/sui/client";
import { Transaction } from "@mysten/sui/transactions";
import { SUI_CLOCK_OBJECT_ID } from "@mysten/sui/utils";
import { PACKAGE_ID } from "../deployed_addresses.json";

export type RaffleType = {
  id: { id: string };
  reward: number;
  owner: string;
  end_date: number;
  min_tickets: number;
  max_tickets: number;
  ticket_price: number;
  participants: string[];
  balance: number;
  winner: string;
  status: number;
  reward_type?: string;
  payment_type?: string;
};

export const USD_DECIMALS = 6;

export const get_datas = async (id: string, suiClient: SuiClient) => {
  const res = await suiClient.getObject({
    id,
    options: {
      showContent: true,
      showType: true,
    },
  });

  const fields = (
    res?.data?.content as unknown as {
      fields: RaffleType;
    }
  )?.fields;

  const objectType = res?.data?.type;
  let reward_type = "0x2::sui::SUI";
  let payment_type = "0x2::sui::SUI";

  if (objectType && objectType.includes("Raffle<")) {
    // Extraire les types entre les <...>
    const typeMatch = objectType.match(/Raffle<([^,]+),\s*([^>]+)>/);
    if (typeMatch) {
      reward_type = typeMatch[1].trim();
      payment_type = typeMatch[2].trim();
    }
  }

  return {
    ...fields,
    reward_type,
    payment_type,
  };
};

export const create_raffle_tx = (
  reward: number,
  end_date: number,
  min_tickets: number,
  max_tickets: number,
  ticket_price: number,
  reward_type: string = "0x2::sui::SUI",
  payment_type: string = "0x2::sui::SUI",
  reward_coins?: string[], // IDs des coins à utiliser pour la récompense (optionnel pour SUI)
) => {
  const tx = new Transaction();

  let reward_coin;

  if (reward_type === "0x2::sui::SUI") {
    // Pour SUI, utiliser tx.gas
    [reward_coin] = tx.splitCoins(tx.gas, [tx.pure.u64(reward)]);
  } else {
    // Pour autres coins, il faut fournir les coins explicitement
    if (!reward_coins || reward_coins.length === 0) {
      throw new Error(
        `Reward coins required for non-SUI reward type: ${reward_type}`,
      );
    }

    // Utiliser le premier coin disponible et le diviser si nécessaire
    const primaryCoin = tx.object(reward_coins[0]);

    if (reward_coins.length > 1) {
      // Merger d'autres coins si disponibles pour avoir assez de fonds
      const otherCoins = reward_coins.slice(1).map((id) => tx.object(id));
      tx.mergeCoins(primaryCoin, otherCoins);
    }

    // Diviser le montant exact requis
    [reward_coin] = tx.splitCoins(primaryCoin, [tx.pure.u64(reward)]);
  }

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::create_raffle`,
    typeArguments: [reward_type, payment_type],
    arguments: [
      tx.sharedObjectRef({
        objectId: SUI_CLOCK_OBJECT_ID,
        initialSharedVersion: 1,
        mutable: false,
      }),
      reward_coin,
      tx.pure.u64(ticket_price),
      tx.pure.u64(end_date),
      tx.pure.u64(min_tickets),
      tx.pure.u64(max_tickets),
    ],
  });

  return tx;
};

// Fonction helper pour créer une transaction create_raffle avec gestion automatique des coins
export const createRaffleTransaction = async (
  suiClient: SuiClient,
  userAddress: string,
  reward: number,
  end_date: number,
  min_tickets: number,
  max_tickets: number,
  ticket_price: number,
  reward_type: string,
  payment_type: string,
) => {
  console.log("Creating raffle transaction...");
  console.log("Reward type:", reward_type);
  console.log("Reward amount:", reward);

  if (reward_type === "0x2::sui::SUI") {
    // Pour SUI, pas besoin de récupérer les coins explicitement
    return create_raffle_tx(
      reward,
      end_date,
      min_tickets,
      max_tickets,
      ticket_price,
      reward_type,
      payment_type,
    );
  } else {
    // Pour autres coins, récupérer les coins de l'utilisateur
    const userCoins = await getUserCoins(suiClient, userAddress, reward_type);

    if (userCoins.length === 0) {
      throw new Error(
        `No coins of type ${reward_type} found for user ${userAddress}`,
      );
    }

    // Vérifier que l'utilisateur a assez de fonds
    const totalBalance = userCoins.reduce(
      (sum, coin) => sum + BigInt(coin.balance),
      0n,
    );
    if (totalBalance < BigInt(reward)) {
      throw new Error(
        `Insufficient balance. Required: ${reward}, Available: ${totalBalance}`,
      );
    }

    const coinIds = userCoins.map((coin) => coin.coinObjectId);
    return create_raffle_tx(
      reward,
      end_date,
      min_tickets,
      max_tickets,
      ticket_price,
      reward_type,
      payment_type,
      coinIds,
    );
  }
};

export const buy_ticket = (
  raffle_address: string,
  amount_tickets: number,
  price: number,
  reward_type: string = "0x2::sui::SUI",
  payment_type: string = "0x2::sui::SUI",
  payment_coins?: string[], // IDs des coins à utiliser pour le paiement (optionnel pour SUI)
) => {
  const tx = new Transaction();

  console.log("reward_type", reward_type);
  console.log("payment_type", payment_type);
  console.log("price", price);
  console.log("payment_coins", payment_coins);

  let payment_coin;

  if (payment_type === "0x2::sui::SUI") {
    // Pour SUI, utiliser tx.gas
    [payment_coin] = tx.splitCoins(tx.gas, [tx.pure.u64(price)]);
  } else {
    // Pour autres coins, il faut fournir les coins explicitement
    if (!payment_coins || payment_coins.length === 0) {
      throw new Error(
        `Payment coins required for non-SUI payment type: ${payment_type}`,
      );
    }

    // Utiliser le premier coin disponible et le diviser si nécessaire
    const primaryCoin = tx.object(payment_coins[0]);

    if (payment_coins.length > 1) {
      // Merger d'autres coins si disponibles pour avoir assez de fonds
      const otherCoins = payment_coins.slice(1).map((id) => tx.object(id));
      tx.mergeCoins(primaryCoin, otherCoins);
    }

    // Diviser le montant exact requis
    [payment_coin] = tx.splitCoins(primaryCoin, [tx.pure.u64(price)]);
  }
  console.log("payment_coin", payment_coin);

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::buy_ticket`,
    typeArguments: [reward_type, payment_type],
    arguments: [
      tx.object(raffle_address),
      tx.pure.u64(amount_tickets),
      payment_coin,
      tx.sharedObjectRef({
        objectId: SUI_CLOCK_OBJECT_ID,
        initialSharedVersion: 1,
        mutable: false,
      }),
    ],
  });

  return tx;
};

export const determine_winner = (
  raffle_address: string,
  reward_type: string = "0x2::sui::SUI",
  payment_type: string = "0x2::sui::SUI",
) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::determine_winner`,
    typeArguments: [reward_type, payment_type],
    arguments: [
      tx.object(raffle_address),
      tx.sharedObjectRef({
        objectId: "0x8",
        initialSharedVersion: 1,
        mutable: false,
      }), // r: &Random
      tx.sharedObjectRef({
        objectId: SUI_CLOCK_OBJECT_ID,
        initialSharedVersion: 1,
        mutable: false,
      }),
    ],
  });

  return tx;
};

export const redeem = (
  raffle_address: string,
  reward_type: string = "0x2::sui::SUI",
  payment_type: string = "0x2::sui::SUI",
) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::redeem`,
    typeArguments: [reward_type, payment_type],
    arguments: [tx.object(raffle_address)],
  });

  return tx;
};

export const redeem_owner = (
  raffle_address: string,
  reward_type: string = "0x2::sui::SUI",
  payment_type: string = "0x2::sui::SUI",
) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::redeem_owner`,
    typeArguments: [reward_type, payment_type],
    arguments: [tx.object(raffle_address)],
  });

  return tx;
};

export const get_raffle_created_events = async (suiClient: SuiClient) => {
  const events: PaginatedEvents = await suiClient.queryEvents({
    query: {
      MoveEventType: `${PACKAGE_ID}::raffles::RaffleCreated`,
    },
  });
  return events.data.map((event) => (event.parsedJson as { id: string }).id);
};

// Fonction pour récupérer les coins d'un type spécifique appartenant à une adresse
export const getUserCoins = async (
  suiClient: SuiClient,
  address: string,
  coinType: string,
) => {
  try {
    const coins = await suiClient.getCoins({
      owner: address,
      coinType: coinType,
    });

    return coins.data.filter((coin) => parseInt(coin.balance) > 0);
  } catch (error) {
    console.error(`Error fetching coins of type ${coinType}:`, error);
    return [];
  }
};

// // Fonction pour obtenir le montant total de coins d'un type pour une adresse
// export const getTotalBalance = async (
//   suiClient: SuiClient,
//   address: string,
//   coinType: string,
// ): Promise<bigint> => {
//   const coins = await getUserCoins(suiClient, address, coinType);
//   return coins.reduce((total, coin) => total + BigInt(coin.balance), 0n);
// };

// Fonction helper pour créer une transaction buy_ticket avec gestion automatique des coins
export const createBuyTicketTransaction = async (
  suiClient: SuiClient,
  userAddress: string,
  raffle_address: string,
  amount_tickets: number,
  price: number,
  reward_type: string,
  payment_type: string,
) => {
  if (payment_type === "0x2::sui::SUI") {
    // Pour SUI, pas besoin de récupérer les coins explicitement
    return buy_ticket(
      raffle_address,
      amount_tickets,
      price,
      reward_type,
      payment_type,
    );
  } else {
    // Pour autres coins, récupérer les coins de l'utilisateur
    const userCoins = await getUserCoins(suiClient, userAddress, payment_type);

    if (userCoins.length === 0) {
      throw new Error(
        `No coins of type ${payment_type} found for user ${userAddress}`,
      );
    }

    // Vérifier que l'utilisateur a assez de fonds
    const totalBalance = userCoins.reduce(
      (sum, coin) => sum + BigInt(coin.balance),
      0n,
    );
    if (totalBalance < BigInt(price)) {
      throw new Error(
        `Insufficient balance. Required: ${price}, Available: ${totalBalance}`,
      );
    }

    const coinIds = userCoins.map((coin) => coin.coinObjectId);
    return buy_ticket(
      raffle_address,
      amount_tickets,
      price,
      reward_type,
      payment_type,
      coinIds,
    );
  }
};
