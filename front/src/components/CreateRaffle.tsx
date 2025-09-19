import { useSignAndExecuteTransaction } from "@mysten/dapp-kit";
import { SUI_DECIMALS } from "@mysten/sui.js/utils";
import { Button, Flex } from "@radix-ui/themes";
import { ChangeEvent, useState } from "react";
import { create_raffle_tx } from "../utils/functions";
import { InputTitle } from "./InputTitle";
import { SelectTitle } from "./SelectTitle";

const oneDay = 1000 * 60 * 60 * 24;
const coins = ["SUI", "USDT", "USDC"];

const handleAmounts = (e: ChangeEvent<HTMLInputElement>) => {
  const number = Number(e.currentTarget.value);
  const value = number < 0 ? 0 : number;
  return value;
};

export function CreateRaffle({
  getRaffles,
}: {
  getRaffles: () => Promise<void>;
}) {
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [rewardCoin, setRewardCoin] = useState(coins[0]);
  const [reward, setReward] = useState(0);
  const [end_date, setEndDate] = useState(Date.now());
  const [min_tickets, setMinTickets] = useState(0);
  const [max_tickets, setMaxTickets] = useState(0);
  const [ticket_price, setTicketPrice] = useState(0);

  const createRaffle = async () => {
    signAndExecute(
      {
        transaction: create_raffle_tx(
          reward * 10 ** SUI_DECIMALS,
          end_date,
          min_tickets,
          max_tickets,
          ticket_price * 10 ** SUI_DECIMALS,
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
    setReward(0);
    setEndDate(Date.now());
    setMinTickets(0);
    setMaxTickets(0);
    setTicketPrice(0);
  };

  return (
    <Flex align="center" direction="column" gap="4">
      <h2>Create a Raffle</h2>
      <Flex mt="2" gap="4" direction={{ initial: "column", md: "row" }}>
        <SelectTitle
          title="Choose a Coin for the reward"
          items={coins}
          defaultValue={rewardCoin}
          setter={setRewardCoin}
        />
        <InputTitle
          title="Reward for the winner in SUI"
          value={reward}
          type="number"
          onChange={(e: ChangeEvent<HTMLInputElement>) => {
            setReward(handleAmounts(e));
          }}
        />
        <InputTitle
          title="End Date"
          type="date"
          min={new Date(Date.now() + oneDay).toISOString().split("T")[0]}
          onChange={(e) =>
            setEndDate(new Date(e.currentTarget.value).getTime())
          }
        />
        <InputTitle
          title="Minimum Tickets"
          placeholder="Minimum Tickets"
          type="number"
          value={min_tickets}
          onChange={(e: ChangeEvent<HTMLInputElement>) => {
            setMinTickets(handleAmounts(e));
          }}
        />
        <InputTitle
          title="Maximum Tickets"
          placeholder="Maximum Tickets"
          type="number"
          value={max_tickets}
          onChange={(e: ChangeEvent<HTMLInputElement>) => {
            setMaxTickets(handleAmounts(e));
          }}
        />
        <InputTitle
          title="Ticket Price in SUI"
          placeholder="Ticket Price in SUI"
          type="number"
          value={ticket_price}
          onChange={(e: ChangeEvent<HTMLInputElement>) => {
            setTicketPrice(handleAmounts(e));
          }}
        />
      </Flex>
      <Button mt="5" size="4" onClick={createRaffle}>
        Create Raffle
      </Button>
    </Flex>
  );
}
