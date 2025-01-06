import { Flex, Text } from "@radix-ui/themes";
import { Raffle } from "./components/Raffle";
import { RaffleType } from "./utils/functions";

export function Raffles({
  raffles,
  getRaffles,
}: {
  raffles: RaffleType[];
  getRaffles: () => Promise<void>;
}) {
  return (
    <Flex my="2" gap="4" wrap="wrap">
      {raffles.length > 0 ? (
        raffles.map((raffle) => (
          <Raffle key={raffle.id.id} raffle={raffle} getRaffles={getRaffles} />
        ))
      ) : (
        <Text>No existing Raffle, be the first who create one !</Text>
      )}
    </Flex>
  );
}
