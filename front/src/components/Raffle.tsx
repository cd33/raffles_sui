import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { Transaction } from "@mysten/sui/dist/cjs/transactions";
import { formatAddress, SUI_DECIMALS } from "@mysten/sui/utils";
import { ChangeEvent, useState } from "react";
import {
  getMockCoinsConfig,
  getProductionCoinsConfig,
} from "../config/mockTokens";
import {
  createBuyTicketTransaction,
  determine_winner,
  RaffleType,
  redeem,
  redeem_owner,
  USD_DECIMALS,
} from "../utils/functions";

const USE_MOCK_TOKENS = import.meta.env.VITE_USE_MOCK_TOKENS === "true";
const coins = USE_MOCK_TOKENS
  ? getMockCoinsConfig()
  : getProductionCoinsConfig();

export function Raffle({
  raffle,
  getRaffles,
}: {
  raffle: RaffleType;
  getRaffles: () => Promise<void>;
}) {
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();
  const [amountTicket, setAmountTicket] = useState(1);
  const raffleAddress = raffle.id.id;
  const endDate = raffle.end_date;
  const rewardType = coins.find(
    (coin) => coin.address === raffle.reward_type,
  )?.name;
  const paymentType = coins.find(
    (coin) => coin.address === raffle.payment_type,
  )?.name;

  const handleTicketAmountChange = (e: ChangeEvent<HTMLInputElement>) => {
    const number = Number(e.currentTarget.value);
    const value =
      number < 1
        ? 1
        : number > Number(raffle.max_tickets)
          ? Number(raffle.max_tickets)
          : number;
    setAmountTicket(value);
  };

  const executeTransaction = (transaction: Transaction) => {
    signAndExecute(
      { transaction },
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

  const buyTicket = async () => {
    if (!account?.address || !raffle.reward_type || !raffle.payment_type) {
      console.error("Missing required data for transaction");
      return;
    }

    try {
      const transaction = await createBuyTicketTransaction(
        suiClient,
        account.address,
        raffleAddress,
        amountTicket,
        amountTicket * raffle.ticket_price,
        raffle.reward_type,
        raffle.payment_type,
      );
      executeTransaction(transaction);
    } catch (error) {
      console.error("Failed to create buy ticket transaction:", error);
    }
  };

  const determineWinner = () => {
    executeTransaction(
      determine_winner(raffleAddress, raffle.reward_type, raffle.payment_type),
    );
  };

  const redeemReward = () => {
    executeTransaction(
      redeem(raffleAddress, raffle.reward_type, raffle.payment_type),
    );
  };

  const redeemRewardOwner = () => {
    executeTransaction(
      redeem_owner(raffleAddress, raffle.reward_type, raffle.payment_type),
    );
  };

  const getStatusColor = (status: number) => {
    switch (status) {
      case 0:
        return "text-green-400";
      case 1:
        return "text-blue-400";
      case 2:
        return "text-red-400";
      default:
        return "text-gray-400";
    }
  };

  const getStatusText = (status: number) => {
    switch (status) {
      case 0:
        return "IN PROGRESS";
      case 1:
        return "COMPLETED";
      case 2:
        return "FAILED";
      default:
        return "UNKNOWN";
    }
  };

  return (
    <div className="w-full max-w-md mx-auto">
      {/* Header with reward */}
      <div className="text-center mb-6">
        <div className="inline-flex items-center space-x-2 bg-gradient-to-r from-yellow-400/20 to-orange-500/20 px-6 py-3 rounded-full border border-yellow-400/30">
          <span className="text-3xl">🏆</span>
          <span className="text-2xl font-bold text-yellow-400">
            {rewardType === "SUI"
              ? raffle.reward / 10 ** SUI_DECIMALS
              : raffle.reward / 10 ** USD_DECIMALS}{" "}
            {rewardType}
          </span>
        </div>
      </div>

      {/* Main info cards */}
      <div className="grid grid-cols-1 gap-4 mb-6">
        <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10">
          <div className="text-xs text-gray-400 mb-2 uppercase tracking-wide">
            👤 Owner
          </div>
          <div className="text-sm font-medium text-white truncate">
            {formatAddress(raffle.owner)}
          </div>
        </div>

        <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10">
          <div className="text-xs text-gray-400 mb-2 uppercase tracking-wide">
            ⏰ End Date
          </div>
          <div className="text-sm font-medium text-white">
            {new Date(Number(endDate)).toLocaleString()}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10">
            <div className="text-xs text-gray-400 mb-2 uppercase tracking-wide">
              🎫 Tickets
            </div>
            <div className="text-lg font-bold text-blue-400">
              {raffle.participants.length}/{raffle.max_tickets}
            </div>
          </div>

          <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10">
            <div className="text-xs text-gray-400 mb-2 uppercase tracking-wide">
              💰 Price
            </div>
            <div className="text-lg font-bold text-green-400">
              {paymentType === "SUI"
                ? raffle.ticket_price / 10 ** SUI_DECIMALS
                : raffle.ticket_price / 10 ** USD_DECIMALS}{" "}
              {paymentType}
            </div>
          </div>
        </div>
      </div>

      {/* Status card */}
      <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10 mb-6">
        <div className="flex items-center justify-between mb-3">
          <span className="text-sm text-gray-400 uppercase tracking-wide">
            Status
          </span>
          <span
            className={`px-3 py-1 rounded-full text-xs font-semibold ${getStatusColor(raffle.status)} bg-current/20`}
          >
            {getStatusText(raffle.status)}
          </span>
        </div>

        {raffle.winner !==
          "0x0000000000000000000000000000000000000000000000000000000000000000" && (
          <div className="pt-3 border-t border-white/10">
            <div className="text-xs text-gray-400 mb-2 uppercase tracking-wide">
              🏆 Winner
            </div>
            <div className="text-sm font-medium text-green-400 truncate">
              {formatAddress(raffle.winner)}
            </div>
          </div>
        )}
      </div>

      {/* Action buttons */}
      <div className="space-y-4">
        {raffle.participants.length !== Number(raffle.max_tickets) &&
          raffle.status === 0 && (
            <div className="bg-white/5 backdrop-blur-sm p-4 rounded-lg border border-white/10">
              <div className="flex items-center space-x-3 mb-3">
                <label className="text-sm text-gray-400 uppercase tracking-wide">
                  Amount:
                </label>
                <input
                  value={amountTicket}
                  type="number"
                  onChange={handleTicketAmountChange}
                  className="w-20 px-3 py-2 bg-white/10 border border-white/20 rounded-lg text-center text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                  min="1"
                  max={raffle.max_tickets}
                />
              </div>
              <button
                className="cursor-pointer w-full px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-semibold rounded-lg transition-colors duration-200 shadow-lg hover:shadow-xl"
                onClick={buyTicket}
              >
                🎫 Buy Ticket
              </button>
            </div>
          )}

        {raffle.status === 0 &&
          (endDate < Date.now() / 1000 ||
            raffle.participants.length === Number(raffle.max_tickets)) && (
            <button
              className="cursor-pointer w-full px-6 py-3 bg-purple-600 hover:bg-purple-700 text-white font-semibold rounded-lg transition-colors duration-200 shadow-lg hover:shadow-xl"
              onClick={determineWinner}
            >
              🎲 Determine Winner
            </button>
          )}

        {raffle.status !== 0 && (
          <div className="space-y-3">
            {raffle.owner === account?.address ? (
              <button
                className="cursor-pointer w-full px-6 py-3 bg-green-600 hover:bg-green-700 text-white font-semibold rounded-lg transition-colors duration-200 shadow-lg hover:shadow-xl"
                onClick={redeemRewardOwner}
              >
                💰 Redeem Owner Reward
              </button>
            ) : (
              <button
                className="cursor-pointer w-full px-6 py-3 bg-yellow-600 hover:bg-yellow-700 text-white font-semibold rounded-lg transition-colors duration-200 shadow-lg hover:shadow-xl"
                onClick={redeemReward}
              >
                🎉 Claim Prize
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
