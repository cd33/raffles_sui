import { useSuiClient } from "@mysten/dapp-kit";
import { useEffect, useState } from "react";
import { Raffles } from "./Raffles";
import {
  get_datas,
  get_raffle_created_events,
  RaffleType,
} from "./utils/functions";

function App() {
  const suiClient = useSuiClient();
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
    <div className="mx-auto px-4 py-8 space-y-12">
      <section>
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold mb-2">🌟 All Raffles</h2>
          <p className="text-gray-400">Discover and join exciting raffles</p>
        </div>
        <Raffles raffles={raffles} getRaffles={getRaffles} />
      </section>
    </div>
  );
}

export default App;
