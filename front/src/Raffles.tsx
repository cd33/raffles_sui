import { SUI_DECIMALS, formatAddress } from "@mysten/sui.js/utils";
import { Flex, Text } from "@radix-ui/themes";
import { RaffleType } from "./utils/functions";

export function Raffles({ raffles }: { raffles: RaffleType[] }) {
  return (
    <Flex my="2" gap="4">
      {raffles.length > 0 ? (
        raffles.map((raffle, id) => (
          <Flex
            direction="column"
            p="4"
            key={id}
            style={{ background: "var(--gray-a2)", borderRadius: "20px" }}
          >
            <Text>Reward: {raffle.reward / 10 ** SUI_DECIMALS} SUI</Text>
            <Text>Owner: {formatAddress(raffle.owner)}</Text>
            <Text>End date: {raffle.end_date}</Text>
            <Text>Min tickets: {raffle.min_tickets}</Text>
            <Text>Max tickets: {raffle.max_tickets}</Text>
            <Text>
              Ticket price: {raffle.ticket_price / 10 ** SUI_DECIMALS} SUI
            </Text>
            <Text>
              Participants:{" "}
              {raffle.participants.length > 0 ? raffle.participants : 0}
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
                ? "IN_PROGRESS"
                : raffle.status === 1
                  ? "COMPLETED"
                  : "FAILED"}
            </Text>
          </Flex>
        ))
      ) : (
        <Text>No existing Raffle, be the first who create one !</Text>
      )}
    </Flex>
  );
}
