import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { SUI_DECIMALS } from "@mysten/sui/utils";
import { ChangeEvent, useState } from "react";
import { useNavigate } from "react-router-dom";
import { InputTitle } from "../components/InputTitle";
import { NFTSelector } from "../components/NFTSelector";
import { SelectTitle } from "../components/SelectTitle";
import {
  getMockCoinsConfig,
  getProductionCoinsConfig,
} from "../config/mockTokens";
import {
  createNFTRaffleTransaction,
  createRaffleTransaction,
  NFTType,
  USD_DECIMALS,
} from "../utils/functions";

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

  // Type de raffle : "coin" ou "nft"
  const [raffleType, setRaffleType] = useState<"coin" | "nft">("coin");

  // Pour les raffles de coins
  const [rewardCoin, setRewardCoin] = useState(coins[0]);
  const [reward, setReward] = useState(1);

  // Pour les raffles de NFTs
  const [selectedNFT, setSelectedNFT] = useState<NFTType | null>(null);

  // Paramètres communs
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
      let transaction;

      if (raffleType === "nft") {
        // Création d'une raffle NFT
        if (!selectedNFT) {
          console.error("No NFT selected");
          return;
        }

        transaction = createNFTRaffleTransaction(
          selectedNFT.id,
          selectedNFT.type,
          end_date,
          min_tickets,
          max_tickets,
          ticket_price *
            10 ** (ticketType.name === "SUI" ? SUI_DECIMALS : USD_DECIMALS),
          ticketType.address,
        );
      } else {
        // Création d'une raffle de coins
        transaction = await createRaffleTransaction(
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
      }

      signAndExecute(
        { transaction },
        {
          onSuccess: () => {
            navigate("/my-raffles");
          },
          onError: (error) => {
            console.error(error);
            setReward(1);
            setSelectedNFT(null);
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
          {/* Sélecteur de type de raffle */}
          <div className="flex justify-center mb-8">
            <div className="bg-white p-6 rounded-lg shadow-md border border-gray-200">
              <h3 className="text-lg text-black font-semibold mb-4 text-center">
                🎯 Raffle Type
              </h3>
              <div className="flex gap-4">
                <button
                  className={`px-6 py-3 rounded-lg font-medium transition ${
                    raffleType === "coin"
                      ? "bg-blue-500 text-white"
                      : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  }`}
                  onClick={() => setRaffleType("coin")}
                >
                  💰 Coin Raffle
                </button>
                <button
                  className={`px-6 py-3 rounded-lg font-medium transition ${
                    raffleType === "nft"
                      ? "bg-purple-500 text-white"
                      : "bg-gray-100 text-gray-700 hover:bg-gray-200"
                  }`}
                  onClick={() => setRaffleType("nft")}
                >
                  🖼️ NFT Raffle
                </button>
              </div>
            </div>
          </div>

          <div className="flex flex-wrap justify-center gap-8 mb-8">
            {raffleType === "coin" ? (
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
            ) : (
              <div className="flex flex-col space-y-4 w-full md:w-2/3 bg-white p-6 rounded-lg shadow-md border border-gray-200">
                <NFTSelector
                  selectedNFT={selectedNFT}
                  onSelect={setSelectedNFT}
                />
              </div>
            )}

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
              className={`text-lg px-8 py-4 rounded-lg shadow-md transition ${
                (raffleType === "coin" && reward > 0) ||
                (raffleType === "nft" && selectedNFT)
                  ? "bg-blue-500 text-white hover:bg-blue-600 cursor-pointer"
                  : "bg-gray-300 text-gray-500 cursor-not-allowed"
              }`}
              onClick={createRaffle}
              disabled={
                (raffleType === "coin" && reward <= 0) ||
                (raffleType === "nft" && !selectedNFT)
              }
            >
              🚀 Launch {raffleType === "nft" ? "NFT " : ""}Raffle
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
