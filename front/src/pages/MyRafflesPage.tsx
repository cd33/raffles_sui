import { useCurrentAccount, useSuiClient } from "@mysten/dapp-kit";
import { useEffect, useState } from "react";
import { Raffles } from "../Raffles";
import {
  get_datas,
  get_raffle_created_events,
  RaffleType,
} from "../utils/functions";

function MyRafflesPage() {
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
    <div className="mx-auto px-4 py-8 space-y-12">
      <section>
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold mb-2">🎰 My Raffles</h2>
          <p className="text-gray-400">Manage your created raffles</p>
        </div>
        {account?.address ? (
          <Raffles
            raffles={raffles.filter(
              (raffle) => raffle.owner === account?.address,
            )}
            getRaffles={getRaffles}
          />
        ) : (
          <p className="text-3xl text-center w-full mt-12">
            Connect your wallet to see your raffles
          </p>
        )}
      </section>
    </div>
  );
}

export default MyRafflesPage;
