import { Link } from "react-router-dom";
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
    <div className="flex flex-wrap gap-6 my-4">
      {raffles.length > 0 ? (
        raffles.map((raffle) => (
          <Raffle key={raffle.id.id} raffle={raffle} getRaffles={getRaffles} />
        ))
      ) : (
        <Link to="/create-raffle" className="text-xl text-center w-full mt-4">
          No existing Raffle, create one !
        </Link>
      )}
    </div>
  );
}
