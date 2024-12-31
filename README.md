# Raffles

## Description

Raffles est un projet utilisant le réseau Sui pour apprendre le langage MOVE.

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

## TODO

create_raffle, buy_ticket, determine_winner, redeem, redeem_owner
faire un front et tester l'aléatoire en local
front vite react: créer raffle, voir les raffles, affichage du nom, interactions
mettre en ligne

## Futur

mode pause avec admincap
tester tous les fails
faire des scenarios de raffle, essayer de tricher, voler les fonds, etc
voir si outils de sécu existent comme pour solidity

## Liens Utiles

- [Exemple de tests Move pour les raffles](https://github.com/MystenLabs/sui/blob/main/examples/move/random/raffles/tests/example_tests.move) : Un exemple de tests Move pour les contrats de raffles sur la blockchain Sui.
- [DoubleUp Fun Raffles](https://www.doubleup.fun/raffles) : Un site web proposant des raffles en ligne.
- [Basic Drand Coin Raffle](https://github.com/Bucket-Protocol/raffle-paper/blob/main/sources/basic_drand_coin_raffle.move) : Un exemple de contrat Move pour une raffle utilisant Drand pour la génération de nombres aléatoires.
- [Small Raffle](https://github.com/MystenLabs/sui-native-randomness/blob/main/small-raffle/small_raffle/sources/small_raffle.move) : Un exemple de petit contrat de raffle utilisant la génération de nombres aléatoires native de Sui.
- [Polymedia Bidder](https://github.com/juzybits/polymedia-bidder/blob/main/src/sui/sources/user.move) : Un exemple de contrat Move pour un système de soumission d'enchères sur Polymedia.
