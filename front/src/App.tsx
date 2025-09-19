import { useCurrentAccount, useSuiClient } from "@mysten/dapp-kit";
import { Container } from "@radix-ui/themes";
import { useEffect, useState } from "react";
import { CreateRaffle } from "./components/CreateRaffle";
import { Navbar } from "./components/Navbar";
import { Raffles } from "./Raffles";
import {
  get_datas,
  get_raffle_created_events,
  RaffleType,
} from "./utils/functions";

function App() {
  const suiClient = useSuiClient();
  const account = useCurrentAccount();
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

  return (
    <>
      <Navbar title="Raffles" />

      <Container>
        <Container>
          <h2 style={{ textAlign: "center", marginTop: "16px" }}>My Raffles</h2>
          <Raffles
            raffles={raffles.filter(
              (raffle) => raffle.owner === account?.address,
            )}
            getRaffles={getRaffles}
          />
        </Container>

        <span
          style={{
            display: "block",
            width: "100%",
            height: "1px",
            backgroundColor: "white",
            marginTop: "24px",
            marginBottom: "16px",
          }}
        />

        <Container>
          <h2 style={{ textAlign: "center" }}>All Raffles</h2>
          <Raffles
            raffles={raffles.filter(
              (raffle) => raffle.owner !== account?.address,
            )}
            getRaffles={getRaffles}
          />
        </Container>

        <span
          style={{
            display: "block",
            width: "100%",
            height: "1px",
            backgroundColor: "white",
            marginTop: "24px",
            marginBottom: "16px",
          }}
        />

        <Container mb="8">
          <CreateRaffle getRaffles={getRaffles} />
        </Container>
      </Container>
    </>
  );
}

export default App;
