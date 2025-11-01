import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from "@mysten/dapp-kit";
import { useEffect, useState } from "react";
import {
  addCoinToWhitelist,
  addNFTToWhitelist,
  formatTypeForDisplay,
  getAdminCap,
  getWhitelistedCoins,
  getWhitelistedNFTs,
  isAdmin,
  removeCoinFromWhitelist,
  removeNFTFromWhitelist,
  SUI_TYPE_MOVE,
} from "../utils/whitelistManager";

type TabType = "coins" | "nfts";

export const AdminPage = () => {
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const { mutate: signAndExecuteTransaction } = useSignAndExecuteTransaction();

  const [isUserAdmin, setIsUserAdmin] = useState(false);
  const [adminCapId, setAdminCapId] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<TabType>("coins");
  const [whitelistedCoins, setWhitelistedCoins] = useState<string[]>([]);
  const [whitelistedNFTs, setWhitelistedNFTs] = useState<string[]>([]);
  const [newItemType, setNewItemType] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Vérifier si l'utilisateur est admin
  useEffect(() => {
    const checkAdmin = async () => {
      if (!account?.address) {
        setIsUserAdmin(false);
        return;
      }

      try {
        const adminStatus = await isAdmin(suiClient, account.address);
        setIsUserAdmin(adminStatus);

        if (adminStatus) {
          const capId = await getAdminCap(suiClient, account.address);
          setAdminCapId(capId);
        }
      } catch (err) {
        console.error("Error checking admin status:", err);
        setIsUserAdmin(false);
      }
    };

    checkAdmin();
  }, [account, suiClient]);

  // Charger les listes
  useEffect(() => {
    const loadWhitelists = async () => {
      try {
        const [coins, nfts] = await Promise.all([
          getWhitelistedCoins(suiClient),
          getWhitelistedNFTs(suiClient),
        ]);
        setWhitelistedCoins(coins);
        setWhitelistedNFTs(nfts);
      } catch (err) {
        console.error("Error loading whitelists:", err);
      }
    };

    loadWhitelists();
    const interval = setInterval(loadWhitelists, 5000);
    return () => clearInterval(interval);
  }, [suiClient]);

  const handleAddItem = async () => {
    if (!adminCapId || !newItemType.trim()) {
      setError("Veuillez entrer un type valide");
      return;
    }

    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const tx =
        activeTab === "coins"
          ? addCoinToWhitelist(adminCapId, newItemType.trim())
          : addNFTToWhitelist(adminCapId, newItemType.trim());

      signAndExecuteTransaction(
        { transaction: tx },
        {
          onSuccess: () => {
            setSuccess(
              `${activeTab === "coins" ? "Coin" : "NFT"} ajouté avec succès`,
            );
            setNewItemType("");
            setTimeout(() => {
              if (activeTab === "coins") {
                getWhitelistedCoins(suiClient).then(setWhitelistedCoins);
              } else {
                getWhitelistedNFTs(suiClient).then(setWhitelistedNFTs);
              }
            }, 2000);
          },
          onError: (err) => {
            setError(`Erreur: ${err.message}`);
          },
        },
      );
    } catch (err) {
      setError(
        `Erreur: ${err instanceof Error ? err.message : "Erreur inconnue"}`,
      );
    } finally {
      setLoading(false);
    }
  };

  const handleRemoveItem = async (itemType: string) => {
    if (!adminCapId) return;

    setLoading(true);
    setError(null);
    setSuccess(null);

    try {
      const tx =
        activeTab === "coins"
          ? removeCoinFromWhitelist(adminCapId, itemType)
          : removeNFTFromWhitelist(adminCapId, itemType);

      signAndExecuteTransaction(
        { transaction: tx },
        {
          onSuccess: () => {
            setSuccess(
              `${activeTab === "coins" ? "Coin" : "NFT"} retiré avec succès`,
            );
            setTimeout(() => {
              if (activeTab === "coins") {
                getWhitelistedCoins(suiClient).then(setWhitelistedCoins);
              } else {
                getWhitelistedNFTs(suiClient).then(setWhitelistedNFTs);
              }
            }, 2000);
          },
          onError: (err) => {
            setError(`Erreur: ${err.message}`);
          },
        },
      );
    } catch (err) {
      setError(
        `Erreur: ${err instanceof Error ? err.message : "Erreur inconnue"}`,
      );
    } finally {
      setLoading(false);
    }
  };

  if (!account) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 flex items-center justify-center">
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-8 text-white">
          <h2 className="text-2xl font-bold mb-4">Accès refusé</h2>
          <p>Veuillez connecter votre wallet pour accéder à cette page.</p>
        </div>
      </div>
    );
  }

  if (!isUserAdmin) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 flex items-center justify-center">
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-8 text-white">
          <h2 className="text-2xl font-bold mb-4">Accès refusé</h2>
          <p>Vous n&apos;avez pas les droits d&apos;administrateur.</p>
        </div>
      </div>
    );
  }

  const currentList =
    activeTab === "coins" ? whitelistedCoins : whitelistedNFTs;

  return (
    <div className="min-h-screen bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 py-12 px-4">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold text-white mb-8 text-center">
          Administration de la Whitelist
        </h1>

        {/* Tabs */}
        <div className="flex gap-4 mb-8">
          <button
            onClick={() => setActiveTab("coins")}
            className={`flex-1 py-3 px-6 rounded-lg font-semibold transition-all ${
              activeTab === "coins"
                ? "bg-white text-purple-900"
                : "bg-white/10 text-white hover:bg-white/20"
            }`}
          >
            Coins ({whitelistedCoins.length})
          </button>
          <button
            onClick={() => setActiveTab("nfts")}
            className={`flex-1 py-3 px-6 rounded-lg font-semibold transition-all ${
              activeTab === "nfts"
                ? "bg-white text-purple-900"
                : "bg-white/10 text-white hover:bg-white/20"
            }`}
          >
            NFTs ({whitelistedNFTs.length})
          </button>
        </div>

        {/* Messages */}
        {error && (
          <div className="mb-6 bg-red-500/20 border border-red-500 text-white p-4 rounded-lg">
            {error}
          </div>
        )}
        {success && (
          <div className="mb-6 bg-green-500/20 border border-green-500 text-white p-4 rounded-lg">
            {success}
          </div>
        )}

        {/* Add Form */}
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6 mb-8">
          <h2 className="text-xl font-bold text-white mb-4">
            Ajouter un {activeTab === "coins" ? "Coin" : "NFT"}
          </h2>
          <div className="flex gap-4">
            <input
              type="text"
              value={newItemType}
              onChange={(e) => setNewItemType(e.target.value)}
              placeholder={`Ex: ${activeTab === "coins" ? SUI_TYPE_MOVE : "0x2::package::Type"}`}
              className="flex-1 px-4 py-3 bg-white/10 border border-white/20 rounded-lg text-white placeholder-white/50 focus:outline-none focus:border-white/40"
            />
            <button
              onClick={handleAddItem}
              disabled={loading || !newItemType.trim()}
              className="px-8 py-3 bg-green-500 hover:bg-green-600 disabled:bg-gray-500 text-white font-semibold rounded-lg transition-colors"
            >
              {loading ? "..." : "Ajouter"}
            </button>
          </div>
          <p className="mt-2 text-sm text-white/60">
            Format: package_id::module::Type (ex: 0x2::sui::SUI)
          </p>
        </div>

        {/* List */}
        <div className="bg-white/10 backdrop-blur-lg rounded-2xl p-6">
          <h2 className="text-xl font-bold text-white mb-4">
            Liste des {activeTab === "coins" ? "Coins" : "NFTs"} whitelistés
          </h2>

          {currentList.length === 0 ? (
            <p className="text-white/60 text-center py-8">
              Aucun {activeTab === "coins" ? "coin" : "NFT"} whitelisté
            </p>
          ) : (
            <div className="space-y-3">
              {currentList.map((item, index) => (
                <div
                  key={index}
                  className="flex items-center justify-between bg-white/5 rounded-lg p-4 hover:bg-white/10 transition-colors"
                >
                  <div className="flex-1 min-w-0">
                    <p className="text-white font-mono text-sm break-all">
                      {item}
                    </p>
                    <p className="text-white/60 text-xs mt-1">
                      {formatTypeForDisplay(item)}
                    </p>
                  </div>
                  <button
                    onClick={() => handleRemoveItem(item)}
                    disabled={loading}
                    className="ml-4 px-4 py-2 bg-red-500 hover:bg-red-600 disabled:bg-gray-500 text-white text-sm font-semibold rounded-lg transition-colors"
                  >
                    Retirer
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Info Box */}
        <div className="mt-8 bg-blue-500/20 border border-blue-500/50 rounded-2xl p-6">
          <h3 className="text-lg font-bold text-white mb-2">ℹ️ Information</h3>
          <p className="text-white/80 text-sm">
            Seuls les {activeTab === "coins" ? "coins" : "NFTs"} présents dans
            cette liste peuvent être utilisés pour créer des raffles.
            Assurez-vous d&apos;ajouter les types corrects au format{" "}
            <code className="bg-white/10 px-2 py-1 rounded">
              package_id::module::Type
            </code>
          </p>
        </div>
      </div>
    </div>
  );
};
