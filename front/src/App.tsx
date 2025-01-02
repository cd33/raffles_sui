import {
  ConnectButton,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { SUI_DECIMALS } from "@mysten/sui.js/utils";
import { Box, Button, Container, Flex, Heading } from "@radix-ui/themes";
import { useEffect, useState } from "react";
import { Raffles } from "./Raffles";
import {
  create_raffle_tx,
  get_datas,
  get_raffle_created_events,
  RaffleType,
} from "./utils/functions";

function App() {
  const suiClient = useSuiClient();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [raffles, setRaffles] = useState<RaffleType[]>([]);

  const getRaffles = async () => {
    const eventsIds = await get_raffle_created_events(suiClient);
    const allRaffles = await Promise.all(
      eventsIds.map(async (id) => await get_datas(id, suiClient)),
    );
    setRaffles(allRaffles);
  };

  useEffect(() => {
    getRaffles();
  }, []);

  const reward = 20 * 10 ** SUI_DECIMALS;
  const end_date = Date.now() + 1000 * 60 * 60 * 24 * 7;
  const min_tickets = 11;
  const max_tickets = 20;
  const ticket_price = 2 * 10 ** SUI_DECIMALS;

  const createRaffle = async () => {
    signAndExecute(
      {
        transaction: create_raffle_tx(
          reward,
          end_date,
          min_tickets,
          max_tickets,
          ticket_price,
        ),
      },
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

  console.log("raffles", raffles);

  return (
    <>
      <Flex
        position="sticky"
        px="4"
        py="2"
        justify="between"
        style={{
          borderBottom: "1px solid var(--gray-a2)",
        }}
      >
        <Box>
          <Heading>Raffles</Heading>
        </Box>

        <Box>
          <ConnectButton />
        </Box>
      </Flex>
      <Container>
        <Container mt="5" pt="2" px="4">
          <Raffles raffles={raffles} />
        </Container>

        <Button mt="5" style={{ width: "100%" }} onClick={createRaffle}>
          Create Raffle
        </Button>
      </Container>
    </>
  );
}

export default App;
