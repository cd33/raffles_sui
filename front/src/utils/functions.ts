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
};

export const get_datas = async (id: string, suiClient: SuiClient) => {
  const res = await suiClient.getObject({
    id,
    options: {
      showContent: true,
    },
  });

  const fields = (
    res?.data?.content as unknown as {
      fields: RaffleType;
    }
  )?.fields;

  return fields;

  // // équivalent de:
  // const { data } = useSuiClientQuery("getObject", {
  //   id: RAFFLE,
  //   options: {
  //     showContent: true,
  //   },
  // });
};

export const create_raffle_tx = (
  reward: number,
  end_date: number,
  min_tickets: number,
  max_tickets: number,
  ticket_price: number,
) => {
  const tx = new Transaction();
  const [payment] = tx.splitCoins(tx.gas, [tx.pure.u64(reward)]);

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::create_raffle`,
    arguments: [
      tx.object(SUI_CLOCK_OBJECT_ID),
      tx.object(payment),
      tx.pure.u64(end_date),
      tx.pure.u64(min_tickets),
      tx.pure.u64(max_tickets),
      tx.pure.u64(ticket_price),
    ],
  });

  return tx;
};

export const buy_ticket = (
  raffle_address: string,
  amount_tickets: number,
  price: number,
) => {
  const tx = new Transaction();
  const [payment] = tx.splitCoins(tx.gas, [tx.pure.u64(price)]);

  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::buy_ticket`,
    arguments: [
      tx.object(raffle_address),
      tx.pure.u64(amount_tickets),
      tx.object(SUI_CLOCK_OBJECT_ID),
      tx.object(payment),
    ],
  });

  return tx;
};

export const determine_winner = (raffle_address: string) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::determine_winner`,
    arguments: [
      tx.object(raffle_address),
      tx.object("0x8"), // r: &Random
      tx.object(SUI_CLOCK_OBJECT_ID),
    ],
  });

  return tx;
};

export const redeem = (raffle_address: string) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::redeem`,
    arguments: [tx.object(raffle_address)],
  });

  return tx;
};

export const redeem_owner = (raffle_address: string) => {
  const tx = new Transaction();
  tx.moveCall({
    target: `${PACKAGE_ID}::raffles::redeem_owner`,
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
