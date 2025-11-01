#[test_only]
module raffles::raffles_tests;

use raffles::raffles::{Self, Raffle};
use sui::balance;
use sui::clock;
use sui::coin::{Self, Coin};
use sui::random::{Self, Random};
use sui::test_scenario::{Self as test, next_tx, ctx};

public struct REWARD has drop {}
public struct PAYMENT has drop {}

const ADMIN: address = @0xABBA;
const USER1: address = @0x1234;
const USER2: address = @0x5678;

#[test]
fun test_create_raffle_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10, // prix du ticket
            2000, // date de fin
            2, // min tickets
            10, // max tickets
            ctx(&mut scenario),
        );

        test::return_shared(registry);
    };

    // Tester l'état dans une nouvelle transaction
    next_tx(&mut scenario, USER1);
    {
        let raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        // Vérifier l'état initial
        let status = raffles::get_status(&raffle);
        assert!(status == 0, 0); // IN_PROGRESS

        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 1); // Pas encore de gagnant

        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() == 0, 2); // Pas encore de participants

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_helper_functions_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(500, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            15,
            2000, // date de fin
            3, // min tickets
            8, // max tickets
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Tester les fonctions getter dans une nouvelle transaction
    next_tx(&mut scenario, USER1);
    {
        let raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        // Tester toutes les fonctions getter
        let status = raffles::get_status(&raffle);
        assert!(status == 0, 0); // IN_PROGRESS

        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 1);

        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() == 0, 2);

        let reward = raffles::get_reward(&raffle);
        assert!(balance::value(reward) == 500, 3);

        let balance = raffles::get_balance(&raffle);
        assert!(balance::value(balance) == 0, 4);

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_buy_tickets_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Acheter des tickets
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(30, ctx(&mut scenario)); // 3 tickets

        raffles::buy_ticket(
            &mut raffle,
            3, // nombre de tickets
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        // Vérifier que les participants ont été ajoutés
        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() == 3, 0);

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_multiple_users_buy_tickets_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur 1 achète 2 tickets
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            2,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        // Vérifier que le total des participants est 2
        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() == 2, 0);

        // Vérifier que le balance contient les paiements
        let balance = raffles::get_balance(&raffle);
        assert!(balance::value(balance) == 20, 1);

        test::return_shared(raffle);
    };

    // Utilisateur 2 achète 3 tickets
    next_tx(&mut scenario, USER2);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(30, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            3,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        // Vérifier que le total des participants est 5
        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() == 5, 2);

        // Vérifier que le balance contient les paiements
        let balance = raffles::get_balance(&raffle);
        assert!(balance::value(balance) == 50, 3); // 2*10 + 3*10 = 50

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_determine_winner_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer l'état Random global (sender @0x0 pour éviter les erreurs du random)
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur 1 achète 2 tickets (nombre minimum pour que la raffle puisse se terminer)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            2,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        test::return_shared(raffle);
    };

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Vérifier que le statut et le winner changent
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        let status_before = raffles::get_status(&raffle);
        assert!(status_before == 0, 1);
        let winner_before = raffles::get_winner(&raffle);
        assert!(winner_before == @0x0, 2);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status_after = raffles::get_status(&raffle);
        assert!(status_after == 1, 3);
        let winner_after = raffles::get_winner(&raffle);
        assert!(winner_after == USER1, 4);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

// Test qui vérifie la logique d'échec sans Random
#[test]
fun test_determine_winner_failed_logic() {
    let mut scenario = test::begin(@0x0);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer l'état Random
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer la raffle avec un minimum élevé
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            5, // min tickets élevé
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Acheter seulement quelques tickets (insuffisant)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_ticket(&mut raffle, 2, payment_coin, &clock, ctx(&mut scenario));
        test::return_shared(raffle);
    };

    // Avancer le temps
    clock::set_for_testing(&mut clock, 2500);

    // Déterminer le gagnant (devrait échouer)
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        let status = raffles::get_status(&raffle);
        assert!(status == 0, 0); // IN_PROGRESS

        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 1);

        raffles::determine_winner(&mut raffle, &random_state, &clock, ctx(&mut scenario));

        // Vérifier que le statut est FAILED
        let status = raffles::get_status(&raffle);
        assert!(status == 2, 2); // FAILED

        // Vérifier qu'aucun gagnant n'a été choisi
        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 3);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_redeem_and_redeem_owner_status_completed_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer l'état Random global (sender @0x0 pour éviter les erreurs du random)
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur 1 achète 2 tickets (nombre minimum pour que la raffle puisse se terminer)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            2,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        test::return_shared(raffle);
    };

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Le vainqueur est déterminé avec status success
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status = raffles::get_status(&raffle);
        assert!(status == 1, 0); // COMPLETED
        let winner = raffles::get_winner(&raffle);
        assert!(winner == USER1, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Redeem de USER1 (gagnant)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 2);

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 3);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<REWARD> a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        // Récupérer le coin qui a été transféré à USER1
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 1000, 4);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Redeem du owner de la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 20, 5);

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 6);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<PAYMENT> a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        // Récupérer le coin qui a été transféré à ADMIN
        let transferred_coin = test::take_from_sender<Coin<PAYMENT>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 20, 7);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_redeem_and_redeem_owner_status_failed_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer l'état Random global (sender @0x0 pour éviter les erreurs du random)
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        // Test avec REWARD pour les deux tokens
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, REWARD>(
            &registry,
            &clock,
            reward_coin,
            200,
            2000,
            6,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur 1 achète 2 tickets
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);
        let payment_coin = coin::mint_for_testing<REWARD>(400, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            2,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        test::return_shared(raffle);
    };

    // Utilisateur 2 achète 3 tickets
    next_tx(&mut scenario, USER2);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);
        let payment_coin = coin::mint_for_testing<REWARD>(600, ctx(&mut scenario));

        raffles::buy_ticket(
            &mut raffle,
            3,
            payment_coin,
            &clock,
            ctx(&mut scenario),
        );

        test::return_shared(raffle);
    };

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Pas de vainqueur et status failed
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status = raffles::get_status(&raffle);
        assert!(status == 2, 0); // FAILED
        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Redeem de USER1
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 2);
        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 1000, 3);

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 1000, 4);
        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 600, 5);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<REWARD> a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        // Récupérer le coin qui a été transféré à USER1
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 400, 6);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Redeem de USER2
    next_tx(&mut scenario, USER2);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 7);
        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 600, 8);

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 1000, 9);
        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 10);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<REWARD> a été transféré à USER2
    next_tx(&mut scenario, USER2);
    {
        // Récupérer le coin qui a été transféré à USER2
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 600, 11);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Redeem du owner de la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 12);

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 13);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<REWARD> a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        // Récupérer le coin qui a été transféré à ADMIN
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 1000, 14);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_redeem_and_redeem_owner_status_failed_no_participant_success() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer l'état Random global (sender @0x0 pour éviter les erreurs du random)
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer la raffle
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            200,
            2000,
            6,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Pas de vainqueur et status failed
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status = raffles::get_status(&raffle);
        assert!(status == 2, 0); // FAILED
        let winner = raffles::get_winner(&raffle);
        assert!(winner == @0x0, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Redeem de USER1, rien ne se passe
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 2);
        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 0, 3);

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 1000, 4);
        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 5);

        test::return_shared(raffle);
    };

    // Redeem du owner de la raffle, il se rembourse
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 6);

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 7);

        test::return_shared(raffle);
    };

    // Vérifier qu'un objet Coin<REWARD> a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        // Récupérer le coin qui a été transféré à ADMIN
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);

        // Vérifier que c'est bien la récompense complète
        assert!(coin::value(&transferred_coin) == 1000, 8);

        // Remettre le coin pour nettoyer le test
        test::return_to_sender(&scenario, transferred_coin);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}
