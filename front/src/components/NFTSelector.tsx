import { useCurrentAccount, useSuiClient } from "@mysten/dapp-kit";
import { useEffect, useState } from "react";
import { getUserNFTs, NFTType } from "../utils/functions";

interface NFTSelectorProps {
  selectedNFT: NFTType | null;
  onSelect: (nft: NFTType | null) => void;
}

export function NFTSelector({ selectedNFT, onSelect }: NFTSelectorProps) {
  const [nfts, setNfts] = useState<NFTType[]>([]);
  const [loading, setLoading] = useState(false);
  const account = useCurrentAccount();
  const suiClient = useSuiClient();

  useEffect(() => {
    const fetchNFTs = async () => {
      if (!account?.address) return;

      setLoading(true);
      try {
        const userNFTs = await getUserNFTs(suiClient, account.address);
        setNfts(userNFTs);
      } catch (error) {
        console.error("Error fetching NFTs:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchNFTs();
  }, [account?.address, suiClient]);

  if (loading) {
    return (
      <div className="flex justify-center items-center p-4">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div>
        <span className="ml-2">Loading your NFTs...</span>
      </div>
    );
  }

  if (nfts.length === 0) {
    return (
      <div className="text-center p-4 text-gray-500">
        <p>No NFTs found in your wallet</p>
        <p className="text-sm">You need to own NFTs to create NFT raffles</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <h3 className="text-lg text-black font-semibold">
        Select an NFT as reward:
      </h3>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 max-h-96 overflow-y-auto">
        {nfts.map((nft) => (
          <div
            key={nft.id}
            className={`border rounded-lg p-4 cursor-pointer transition-all ${
              selectedNFT?.id === nft.id
                ? "border-blue-500 bg-blue-50"
                : "border-gray-200 hover:border-gray-300"
            }`}
            onClick={() => onSelect(selectedNFT?.id === nft.id ? null : nft)}
          >
            {nft.image_url && (
              <img
                src={nft.image_url}
                alt={nft.name}
                className="w-full h-32 object-cover rounded-md mb-2"
                onError={(e) => {
                  (e.target as HTMLImageElement).style.display = "none";
                }}
              />
            )}
            <h4 className="font-medium text-sm text-black truncate">
              {nft.name}
            </h4>
            <p className="text-xs text-gray-500 truncate">{nft.description}</p>
            <p className="text-xs text-gray-400 truncate mt-1">
              ID: {nft.id.slice(0, 8)}...{nft.id.slice(-8)}
            </p>
          </div>
        ))}
      </div>
      {selectedNFT && (
        <div className="p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <p className="text-sm text-black">
            <strong>Selected:</strong> {selectedNFT.name}
          </p>
        </div>
      )}
    </div>
  );
}
