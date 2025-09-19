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
