import deployedAddresses from "../deployed_addresses.json";

interface ExtendedDeployedAddresses {
  PACKAGE_ID: string;
  ADMIN_CAP: string;
  RAFFLE: string;
  MOCK_USDT_TREASURY?: string;
  MOCK_USDC_TREASURY?: string;
  MOCK_USDT_TYPE?: string;
  MOCK_USDC_TYPE?: string;
}

const addresses = deployedAddresses as ExtendedDeployedAddresses;

export const MOCK_TOKENS_CONFIG = {
  PACKAGE_ID: addresses.PACKAGE_ID,

  TREASURY_CAPS: {
    USDT: addresses.MOCK_USDT_TREASURY || null,
    USDC: addresses.MOCK_USDC_TREASURY || null,
  },

  COIN_TYPES: {
    MOCK_USDT:
      addresses.MOCK_USDT_TYPE ||
      `${addresses.PACKAGE_ID}::mock_usdt::MOCK_USDT`,
    MOCK_USDC:
      addresses.MOCK_USDC_TYPE ||
      `${addresses.PACKAGE_ID}::mock_usdc::MOCK_USDC`,
  },
};

// Configuration des coins pour le développement
export function getMockCoinsConfig() {
  return [
    { name: "SUI", address: "0x2::sui::SUI" },
    { name: "USDT (Mock)", address: MOCK_TOKENS_CONFIG.COIN_TYPES.MOCK_USDT },
    { name: "USDC (Mock)", address: MOCK_TOKENS_CONFIG.COIN_TYPES.MOCK_USDC },
  ];
}

// Configuration des coins pour la production (vrais tokens)
export function getProductionCoinsConfig() {
  return [
    { name: "SUI", address: "0x2::sui::SUI" },
    {
      name: "USDT",
      address:
        "0x375f70cf2ae4c00bf37117d0c85a2c71545e6ee05c4a5c7d282cd66a4504b068::usdt::USDT",
    },
    {
      name: "USDC",
      address:
        "0xdba34672e30cb065b1f93e3ab55318768fd6fef66c15942c9f7cb846e2f900e7::usdc::USDC",
    },
  ];
}
