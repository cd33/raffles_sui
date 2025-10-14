import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { SUI_DECIMALS } from "@mysten/sui/utils";
import { ChangeEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { InputTitle } from "../components/InputTitle";
import { SelectTitle } from "../components/SelectTitle";
import {
  getMockCoinsConfig,
  getProductionCoinsConfig,
} from "../config/mockTokens";
import { createRaffleTransaction, USD_DECIMALS } from "../utils/functions";

const oneDay = 1000 * 60 * 60 * 24;

const USE_MOCK_TOKENS = import.meta.env.VITE_USE_MOCK_TOKENS === "true";
const coins = USE_MOCK_TOKENS
  ? getMockCoinsConfig()
  : getProductionCoinsConfig();

const handleAmounts = (e: ChangeEvent<HTMLInputElement>) => {
  const number = Number(e.currentTarget.value);
  const value = number < 0 ? 0 : number;
  return value;
};

function CreateRafflePage() {
  const navigate = useNavigate();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const [rewardCoin, setRewardCoin] = useState(coins[0]);
  const [reward, setReward] = useState(1);
  const [end_date, setEndDate] = useState(Date.now() + oneDay * 7);
  const [min_tickets, setMinTickets] = useState(5);
  const [max_tickets, setMaxTickets] = useState(10);
  const [ticket_price, setTicketPrice] = useState(1);
  const [ticketType, setTicketType] = useState(coins[0]);

  const createRaffle = async () => {
    if (!account?.address) {
      console.error("No account connected");
      return;
    }

    try {
      const transaction = await createRaffleTransaction(
        suiClient,
        account.address,
        reward *
          10 ** (rewardCoin.name === "SUI" ? SUI_DECIMALS : USD_DECIMALS),
        end_date,
        min_tickets,
        max_tickets,
        ticket_price *
          10 ** (ticketType.name === "SUI" ? SUI_DECIMALS : USD_DECIMALS),
        rewardCoin.address,
        ticketType.address,
      );

      signAndExecute(
        { transaction },
        {
          onSuccess: () => {
            navigate("/my-raffles");
          },
          onError: (error) => {
            console.error(error);
            setReward(1);
            setEndDate(Date.now() + oneDay * 7);
            setMinTickets(5);
            setMaxTickets(10);
            setTicketPrice(1);
          },
        },
      );
    } catch (error) {
      console.error("Failed to create transaction:", error);
    }
  };

  return (
    <div className="w-full mx-auto">
      <div className="text-center mb-8">
        <h2 className="text-3xl font-bold mb-2">🎪 Create New Raffle</h2>
        <p className="text-gray-400">
          Fill in the details below to create a new raffle
        </p>
      </div>
      {account?.address ? (
        <>
          <div className="flex flex-wrap justify-center gap-8 mb-8">
            <div className="flex flex-col space-y-4 w-full md:w-1/3 bg-white p-6 rounded-lg shadow-md border border-gray-200">
              <SelectTitle
                title="💰 Reward Coin"
                items={coins}
                defaultValue={rewardCoin}
                setter={setRewardCoin}
              />
              <InputTitle
                title="🎁 Reward Amount"
                value={reward}
                type="number"
                onChange={(e: ChangeEvent<HTMLInputElement>) => {
                  setReward(handleAmounts(e));
                }}
              />
            </div>

            <div className="flex flex-col space-y-4 w-full md:w-1/3 bg-white p-6 rounded-lg shadow-md border border-gray-200">
              <InputTitle
                title="📅 End Date"
                type="date"
                value={new Date(end_date).toISOString().split("T")[0]}
                min={new Date(Date.now() + oneDay).toISOString().split("T")[0]}
                onChange={(e) =>
                  setEndDate(new Date(e.currentTarget.value).getTime())
                }
              />
            </div>

            <div className="flex flex-col space-y-4 w-full md:w-1/3 bg-white p-6 rounded-lg shadow-md border border-gray-200">
              <InputTitle
                title="🎫 Minimum Tickets"
                type="number"
                value={min_tickets}
                onChange={(e: ChangeEvent<HTMLInputElement>) => {
                  setMinTickets(handleAmounts(e));
                }}
              />
              <InputTitle
                title="🎯 Maximum Tickets"
                type="number"
                value={max_tickets}
                onChange={(e: ChangeEvent<HTMLInputElement>) => {
                  setMaxTickets(handleAmounts(e));
                }}
              />
            </div>

            <div className="flex flex-col space-y-4 w-full md:w-1/3 bg-white p-6 rounded-lg shadow-md border border-gray-200">
              <SelectTitle
                title="💰 Payment Coin"
                items={coins}
                defaultValue={ticketType}
                setter={setTicketType}
              />
              <InputTitle
                title="💵 Ticket Price"
                type="number"
                value={ticket_price}
                onChange={(e: ChangeEvent<HTMLInputElement>) => {
                  setTicketPrice(handleAmounts(e));
                }}
              />
            </div>
          </div>
          <div className="flex justify-center">
            <button
              className="cursor-pointer text-lg px-8 py-4 bg-blue-500 text-white rounded-lg shadow-md hover:bg-blue-600 transition"
              onClick={createRaffle}
            >
              🚀 Launch Raffle
            </button>
          </div>
        </>
      ) : (
        <p className="text-3xl text-center w-full mt-12">
          Connect your wallet to create a raffle
        </p>
      )}
    </div>
  );
}

export default CreateRafflePage;
