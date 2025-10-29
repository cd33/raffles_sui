# Sui Raffles

## Déployer contract

Ajuster les variables dans le fichier `.env` :

```env
PRIVATE_KEY=""
VITE_NETWORK_URL=""
```

Puis lancer la commande :

```bash
pnpm run deploy
```

## Ajouter un compte SUI au SDK local

```bash
sui keytool convert <clé_privée_base64>
sui keytool import <clé_bech32> ed25519 --alias <nom_alias>
sui client switch --address <alias_ou_adresse>
sui client addresses
sui client envs
sui client switch --env local
sui client faucet
```

## Ajouter les addresses à la wallet extension (nightly)

### Configurer Nightly (capable d'avoir un réseau local)

- Installer l'extension Nightly Wallet
- Créer un nouveau wallet ou importer un wallet existant avec une seed phrase
- Aller dans les paramètres (Settings) -> RPC -> Mainnet -> Custom RPC ->
  Ajouter l'URL du local network (ex: `http://127.0.0.1:9000`)

### Importer les clés privées dans Nightly

```bash
sui keytool list
sui keytool export --key-identity 0x265eefb3bf8772b66049769ff4ad7b582d0e3cbeffffc9930c16d81339b3a0b8
la clé commence par "suiprivkey"
```

### Coins et NFTs sont transférables entre wallets depuis Nightly
