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

## Compiler

```sh
sui move build
```

## Tester

```sh
sui move test
```

### Coverage

```sh
sui move test --coverage --dev
sui move coverage summary
sui move coverage source --module raffles
```

## TODO

- mettre à jour le front
- faire de grande simulation scenarisées, plusieurs fois redeem_owner, plusieurs fois redeem meme user... essayer de casser le contrat

- ajouter fonctions admin (pause, resume, withdraw funds), autre ?
- ajouter tax sur les redeem (seulement les success ?)
- adapter le front
- ajouter les NFTs
- adapter le front
- Mettre en ligne avec Vercel

## Futur

- check uml, en fct virer admincap ?
- faire des scenarios de raffle, essayer de tricher, voler les fonds, etc
- voir si outils de sécu existent comme pour solidity
- min_ticket peut etre égal à max_ticket ?

## Liens Utiles

- [Exemple de tests Move pour les raffles](https://github.com/MystenLabs/sui/blob/main/examples/move/random/raffles/tests/example_tests.move) : Un exemple de tests Move pour les contrats de raffles sur la blockchain Sui.
- [DoubleUp Fun Raffles](https://www.doubleup.fun/raffles) : Un site web proposant des raffles en ligne.
- [Basic Drand Coin Raffle](https://github.com/Bucket-Protocol/raffle-paper/blob/main/sources/basic_drand_coin_raffle.move) : Un exemple de contrat Move pour une raffle utilisant Drand pour la génération de nombres aléatoires.
- [Small Raffle](https://github.com/MystenLabs/sui-native-randomness/blob/main/small-raffle/small_raffle/sources/small_raffle.move) : Un exemple de petit contrat de raffle utilisant la génération de nombres aléatoires native de Sui.
- [Polymedia Bidder](https://github.com/juzybits/polymedia-bidder/blob/main/src/sui/sources/user.move) : Un exemple de contrat Move pour un système de soumission d'enchères sur Polymedia.
- [Aptos Raffle](https://github.com/mokshyaprotocol/aptos-raffle/blob/main/sources/raffle.move)
- [Linear Vesting Contract Example](https://github.com/Origin-Byte/nft-protocol/blob/e8e8efd77ab15d7b2cf30958fd748dbb3afbdaab/contracts/originmate/sources/linear_vesting.move#L157)

## Events

```sh
use sui::event;
public struct RandomNumber has copy, drop {
    random_number: u64,
}

public fun test_random(r: &Random, ctx: &mut TxContext) {
    let mut generator = r.new_generator(ctx);
    let random_number = generator.generate_u64_in_range(1, 10);
    event::emit(RandomNumber { random_number });
    random_number;
}
```

```sh
const txResult = await signAndExecute({
    transaction: tx
});

await new Promise((resolve) => setTimeout(resolve, 2000));

const eventsResult = await client.queryEvents({
    query: { Transaction: txResult.digest }
});

const firstEvent = eventsResult.data[0]?.parsedJson
```
