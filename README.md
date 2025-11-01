# Raffles

## Description

Raffles est un projet utilisant le réseau Sui pour apprendre le langage MOVE.

## Installation

```bash
curl https://sh.rustup.rs -sSf | sh
sudo apt-get install curl git-all cmake gcc libssl-dev pkg-config libclang-dev libpq-dev build-essential
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui --features tracing
sui client new-env --alias local --rpc http://127.0.0.1:9000
```

## Upgrade Sui

```bash
rustup update stable
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch testnet sui --features tracing
```

## Créer package

```sh
sui move new my_first_package
```

## Client App with Sui TypeScript SDK

```sh
pnpm create @mysten/dapp
```

## Démarrer un local network

```sh
RUST_LOG="off,sui_node=info" sui start --with-faucet --force-regenesis
sui client switch --env local
sui client faucet
```

## Lancer le front (après avoir démarrer le local network)

```sh
cd front
pnpm run deploy
pnpm dev
```

## Seed le wallet 2

```sh
sui client addresses
sui client switch --address 0x7097cf9a9a572cb87a74c2c0f114d61792a17d6bd7e8eafa2796b1c49e32b741
sui client faucet
npx tsx scripts/mint-mock-tokens.ts
sui client switch --address 0x265eefb3bf8772b66049769ff4ad7b582d0e3cbeffffc9930c16d81339b3a0b8
```

## Compiler

```sh
sui move build
```

## Tester

```sh
sui move test
```

## Coverage

```sh
sui move test --coverage --dev
sui move coverage summary
sui move coverage source --module raffles
```

## Debug

```move
use std::debug;
debug::print(&std::string::utf8(b"toto"));
```

## TODO

- ajouter tax sur les redeem (seulement les success ?)
- ajouter fonctions admin (pause, resume, withdraw funds), autre ?
- adapter le front
- tests: faire de grande simulation scenarisées, plusieurs fois redeem_owner, plusieurs fois redeem meme user... essayer de casser le contrat
- Mettre en ligne avec une alternative à Vercel

## Futur

- ADMIN:
- avoir des raffles admin où on peut:
  - choisir un nb de ticket max par wallet (implémenter sur les raffles de base ?)
  - utiliser un nft ou coin non listé
  - pouvoir pauser/resumer une raffle ou alors tout le contrat ?
  - autres points ?
- blacklister des addresses:

  - pouvoir consulter et modifier cette liste

- faire des scenarios de raffle, essayer de tricher, voler les fonds, etc
- voir si outils de sécu existent comme pour solidity
- min_ticket peut etre égal à max_ticket, est ce souhaité une raffle avec un nombre exact de tickets ?

## Liens Utiles

- [Exemple de tests Move pour les raffles](https://github.com/MystenLabs/sui/blob/main/examples/move/random/raffles/tests/example_tests.move) : Un exemple de tests Move pour les contrats de raffles sur la blockchain Sui.
- [DoubleUp Fun Raffles](https://www.doubleup.fun/raffles) : Un site web proposant des raffles en ligne.
- [Basic Drand Coin Raffle](https://github.com/Bucket-Protocol/raffle-paper/blob/main/sources/basic_drand_coin_raffle.move) : Un exemple de contrat Move pour une raffle utilisant Drand pour la génération de nombres aléatoires.
- [Small Raffle](https://github.com/MystenLabs/sui-native-randomness/blob/main/small-raffle/small_raffle/sources/small_raffle.move) : Un exemple de petit contrat de raffle utilisant la génération de nombres aléatoires native de Sui.
- [Polymedia Bidder](https://github.com/juzybits/polymedia-bidder/blob/main/src/sui/sources/user.move) : Un exemple de contrat Move pour un système de soumission d'enchères sur Polymedia.
- [Aptos Raffle](https://github.com/mokshyaprotocol/aptos-raffle/blob/main/sources/raffle.move)
- [Linear Vesting Contract Example](https://github.com/Origin-Byte/nft-protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/originmate/sources/linear_vesting.move#L157)
