#[test_only]
module raffles::nft_raffle_tests;

use raffles::mock_nft::{Self, MockNFT};
use raffles::mock_usdt::{Self, MOCK_USDT};
use raffles::raffles::{Self, NFTRaffle};
use sui::clock;
use sui::coin;
use sui::random::{Self, Random};
use sui::test_scenario;

const RAFFLE_OWNER: address = @0x1;
const PARTICIPANT1: address = @0x2;
const PARTICIPANT2: address = @0x3;

// Constantes pour la raffle
const TICKET_PRICE: u64 = 100_000; // 0.1 USDT (6 décimales)
const MIN_TICKETS: u64 = 2;
const MAX_TICKETS: u64 = 10;

#[test]
fun test_create_nft_raffle() {
    let mut scenario = test_scenario::begin(RAFFLE_OWNER);
    let clock = clock::create_for_testing(scenario.ctx());

    // Créer une collection et mint un NFT pour la raffle
    let mut collection_cap = mock_nft::init_for_testing(scenario.ctx());
    let test_nft = mock_nft::mint_for_testing(&mut collection_cap, scenario.ctx());

    // Créer la raffle NFT
    let end_date = clock::timestamp_ms(&clock) + 86400000; // +24h
    raffles::create_nft_raffle<MockNFT, MOCK_USDT>(
        &clock,
        test_nft,
        TICKET_PRICE,
        end_date,
        MIN_TICKETS,
        MAX_TICKETS,
        scenario.ctx(),
    );

    // Nettoyer
    mock_nft::destroy_for_testing(collection_cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_buy_nft_tickets() {
    let mut scenario = test_scenario::begin(RAFFLE_OWNER);
    let clock = clock::create_for_testing(scenario.ctx());

    // Setup: créer NFT et raffle
    let mut collection_cap = mock_nft::init_for_testing(scenario.ctx());
    let test_nft = mock_nft::mint_for_testing(&mut collection_cap, scenario.ctx());

    let end_date = clock::timestamp_ms(&clock) + 86400000;
    raffles::create_nft_raffle<MockNFT, MOCK_USDT>(
        &clock,
        test_nft,
        TICKET_PRICE,
        end_date,
        MIN_TICKETS,
        MAX_TICKETS,
        scenario.ctx(),
    );

    // Passer au prochain tour pour récupérer la raffle partagée
    scenario.next_tx(PARTICIPANT1);
    let mut nft_raffle = scenario.take_shared<NFTRaffle<MockNFT, MOCK_USDT>>();

    // Créer des tokens USDT pour l'achat
    let treasury_cap = mock_usdt::init_for_testing(scenario.ctx());
    let payment = coin::mint_for_testing<MOCK_USDT>(TICKET_PRICE * 2, scenario.ctx());

    // Acheter 2 tickets
    raffles::buy_nft_ticket(
        &mut nft_raffle,
        2,
        payment,
        &clock,
        scenario.ctx(),
    );

    // Vérifier que les participants ont été ajoutés
    let participants = raffles::get_nft_participants(&nft_raffle);
    assert!(participants.length() == 2, 0);
    assert!(*participants.borrow(0) == PARTICIPANT1, 1);
    assert!(*participants.borrow(1) == PARTICIPANT1, 2);

    // Nettoyer
    test_scenario::return_shared(nft_raffle);
    sui::test_utils::destroy(treasury_cap);
    mock_nft::destroy_for_testing(collection_cap);
    clock::destroy_for_testing(clock);
    scenario.end();
}

#[test]
fun test_nft_raffle_complete_flow() {
    let mut scenario = test_scenario::begin(@0x0);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

    // Créer l'état Random global
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(test_scenario::ctx(&mut scenario));
    };

    // Setup
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    let mut collection_cap = mock_nft::init_for_testing(test_scenario::ctx(&mut scenario));
    let test_nft = mock_nft::mint_for_testing(
        &mut collection_cap,
        test_scenario::ctx(&mut scenario),
    );
    let treasury_cap = mock_usdt::init_for_testing(test_scenario::ctx(&mut scenario));

    // Créer la raffle
    let end_date = clock::timestamp_ms(&clock) + 86400000;
    raffles::create_nft_raffle<MockNFT, MOCK_USDT>(
        &clock,
        test_nft,
        TICKET_PRICE,
        end_date,
        MIN_TICKETS,
        MAX_TICKETS,
        test_scenario::ctx(&mut scenario),
    );

    // Les participants achètent des tickets
    test_scenario::next_tx(&mut scenario, PARTICIPANT1);
    let mut nft_raffle = test_scenario::take_shared<NFTRaffle<MockNFT, MOCK_USDT>>(&scenario);
    let payment1 = coin::mint_for_testing<MOCK_USDT>(
        TICKET_PRICE * 2,
        test_scenario::ctx(&mut scenario),
    );
    raffles::buy_nft_ticket(
        &mut nft_raffle,
        2,
        payment1,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    test_scenario::next_tx(&mut scenario, PARTICIPANT2);
    let payment2 = coin::mint_for_testing<MOCK_USDT>(
        TICKET_PRICE,
        test_scenario::ctx(&mut scenario),
    );
    raffles::buy_nft_ticket(
        &mut nft_raffle,
        1,
        payment2,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Avancer le temps pour que la raffle expire
    clock::increment_for_testing(&mut clock, 86400001);

    // Déterminer le gagnant
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    let random_state = test_scenario::take_shared<Random>(&scenario);

    raffles::determine_nft_winner(
        &mut nft_raffle,
        &random_state,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Vérifier que la raffle est terminée
    assert!(raffles::get_nft_status(&nft_raffle) == 1, 0); // COMPLETED

    let winner = raffles::get_nft_winner(&nft_raffle);
    assert!(winner == PARTICIPANT1 || winner == PARTICIPANT2, 1);

    // Le gagnant récupère le NFT
    test_scenario::next_tx(&mut scenario, winner);
    raffles::redeem_nft(&mut nft_raffle, test_scenario::ctx(&mut scenario));

    // Le propriétaire récupère les fonds
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    raffles::redeem_nft_owner(&mut nft_raffle, test_scenario::ctx(&mut scenario));

    // Nettoyer
    test_scenario::return_shared(nft_raffle);
    test_scenario::return_shared(random_state);
    sui::test_utils::destroy(treasury_cap);
    mock_nft::destroy_for_testing(collection_cap);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}

#[test]
fun test_nft_raffle_failed_refund() {
    let mut scenario = test_scenario::begin(@0x0);
    let mut clock = clock::create_for_testing(test_scenario::ctx(&mut scenario));

    // Créer l'état Random global
    test_scenario::next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(test_scenario::ctx(&mut scenario));
    };

    // Setup avec une raffle qui nécessite MIN_TICKETS = 5
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    let mut collection_cap = mock_nft::init_for_testing(test_scenario::ctx(&mut scenario));
    let test_nft = mock_nft::mint_for_testing(
        &mut collection_cap,
        test_scenario::ctx(&mut scenario),
    );
    let treasury_cap = mock_usdt::init_for_testing(test_scenario::ctx(&mut scenario));

    let end_date = clock::timestamp_ms(&clock) + 86400000;
    raffles::create_nft_raffle<MockNFT, MOCK_USDT>(
        &clock,
        test_nft,
        TICKET_PRICE,
        end_date,
        5, // MIN_TICKETS = 5
        10, // MAX_TICKETS = 10
        test_scenario::ctx(&mut scenario),
    );

    // Un seul participant achète 2 tickets (insuffisant)
    test_scenario::next_tx(&mut scenario, PARTICIPANT1);
    let mut nft_raffle = test_scenario::take_shared<NFTRaffle<MockNFT, MOCK_USDT>>(&scenario);
    let payment = coin::mint_for_testing<MOCK_USDT>(
        TICKET_PRICE * 2,
        test_scenario::ctx(&mut scenario),
    );
    raffles::buy_nft_ticket(&mut nft_raffle, 2, payment, &clock, test_scenario::ctx(&mut scenario));

    // Avancer le temps pour expirer la raffle
    clock::increment_for_testing(&mut clock, 86400001);

    // Déterminer le résultat (devrait échouer car pas assez de participants)
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    let random_state = test_scenario::take_shared<Random>(&scenario);
    raffles::determine_nft_winner(
        &mut nft_raffle,
        &random_state,
        &clock,
        test_scenario::ctx(&mut scenario),
    );

    // Vérifier que la raffle a échoué
    assert!(raffles::get_nft_status(&nft_raffle) == 2, 0); // FAILED

    // Le participant récupère son remboursement
    test_scenario::next_tx(&mut scenario, PARTICIPANT1);
    raffles::redeem_nft(&mut nft_raffle, test_scenario::ctx(&mut scenario));

    // Le propriétaire récupère son NFT
    test_scenario::next_tx(&mut scenario, RAFFLE_OWNER);
    raffles::redeem_nft_owner(&mut nft_raffle, test_scenario::ctx(&mut scenario));

    // Vérifier qu'il n'y a plus de NFT dans la raffle
    assert!(!raffles::has_nft_reward(&nft_raffle), 1);

    // Nettoyer
    test_scenario::return_shared(nft_raffle);
    test_scenario::return_shared(random_state);
    sui::test_utils::destroy(treasury_cap);
    mock_nft::destroy_for_testing(collection_cap);
    clock::destroy_for_testing(clock);
    test_scenario::end(scenario);
}
