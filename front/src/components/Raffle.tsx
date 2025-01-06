import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
} from "@mysten/dapp-kit";
import { formatAddress, SUI_DECIMALS } from "@mysten/sui.js/utils";
import { Transaction } from "@mysten/sui/dist/cjs/transactions";
import { Button, Flex, Text } from "@radix-ui/themes";
import { useState } from "react";
import {
  buy_ticket,
  determine_winner,
  RaffleType,
  redeem,
  redeem_owner,
} from "../utils/functions";

export function Raffle({
  raffle,
  getRaffles,
}: {
  raffle: RaffleType;
  getRaffles: () => Promise<void>;
}) {
  const account = useCurrentAccount();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [amountTicket, setAmountTicket] = useState(1);
  const raffleAddress = raffle.id.id;
  const endDate = raffle.end_date;

  const handleTicketAmountChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const number = Number(e.currentTarget.value);
    const value =
      number < 1
        ? 1
        : number > raffle.max_tickets
          ? raffle.max_tickets
          : number;
    setAmountTicket(value);
  };

  const executeTransaction = (transaction: Transaction) => {
    signAndExecute(
      { transaction },
      {
        onSuccess: () => {
          setTimeout(() => {
            getRaffles();
          }, 1000);
        },
        onError: (error) => {
          console.error(error);
        },
      },
    );
  };

  const buyTicket = () => {
    executeTransaction(
      buy_ticket(
        raffleAddress,
        amountTicket,
        amountTicket * raffle.ticket_price,
      ),
    );
  };

  const determineWinner = () => {
    executeTransaction(determine_winner(raffleAddress));
  };

  const redeemReward = () => {
    executeTransaction(redeem(raffleAddress));
  };

  const redeemRewardOwner = () => {
    executeTransaction(redeem_owner(raffleAddress));
  };

  return (
    <Flex
      direction="column"
      p="4"
      style={{ background: "var(--gray-a2)", borderRadius: "20px" }}
    >
      <Text>Reward: {raffle.reward / 10 ** SUI_DECIMALS} SUI</Text>
      <Text>Owner: {formatAddress(raffle.owner)}</Text>
      <Text>End date: {endDate}</Text>
      <Text>Min tickets: {raffle.min_tickets}</Text>
      <Text>Max tickets: {raffle.max_tickets}</Text>
      <Text>Ticket price: {raffle.ticket_price / 10 ** SUI_DECIMALS} SUI</Text>
      <Text>
        Participants:{" "}
        {raffle.participants.length > 0 ? raffle.participants.length : 0}
      </Text>
      <Text>Balance: {raffle.balance / 10 ** SUI_DECIMALS} SUI</Text>
      <Text>
        Winner:{" "}
        {raffle.winner ===
        "0x0000000000000000000000000000000000000000000000000000000000000000"
          ? "No winner yet"
          : formatAddress(raffle.winner)}
      </Text>
      <Text>
        Status:{" "}
        {raffle.status === 0
          ? "IN PROGRESS"
          : raffle.status === 1
            ? "COMPLETED"
            : "FAILED"}
      </Text>

      <Flex direction="column" gap="2" mt="4">
        {raffle.participants.length != raffle.max_tickets && (
          <>
            <input
              value={amountTicket}
              type="number"
              onChange={handleTicketAmountChange}
            />
            <Button onClick={buyTicket}>Buy Ticket</Button>
          </>
        )}
        {raffle.status === 0 &&
          (endDate < Date.now() / 1000 ||
            raffle.participants.length == raffle.max_tickets) && (
            <Button onClick={determineWinner}>Determine Winner</Button>
          )}

        {raffle.status !== 0 && (
          <>
            <Button onClick={redeemRewardOwner}>Redeem Reward Owner</Button>
            {raffle.owner === account?.address && (
              <Button onClick={redeemReward}>Redeem Reward</Button>
            )}
          </>
        )}
      </Flex>
    </Flex>
  );
}
