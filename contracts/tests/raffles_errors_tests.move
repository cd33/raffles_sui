#[test_only]
module raffles::raffles_errors_tests;

use raffles::mock_nft::{Self, MockNFT};
use raffles::mock_usdt::MOCK_USDT;
use raffles::raffles::{Self, Raffle};
use sui::clock;
use sui::coin;
use sui::random::{Self, Random};
use sui::test_scenario::{Self as test, next_tx, ctx};

public struct REWARD has drop {}
public struct PAYMENT has drop {}
public struct OTHER_MOCK_NFT has drop {}

const ADMIN: address = @0xABBA;
const USER1: address = @0x1234;

#[test]
#[expected_failure(abort_code = 0, location = raffles)]
fun test_determine_winner_game_already_completed() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer l'état Random global (sender @0x0 pour éviter les erreurs du random)
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

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

    // Vérifier que le statut change
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        let status_before = raffles::get_status(&raffle);
        assert!(status_before == 0, 0);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status_after = raffles::get_status(&raffle);
        assert!(status_after == 1, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // On retente de déterminer le gagnant (devrait échouer car le state a changé)
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

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0, location = raffles)]
fun test_redeem_game_already_completed() {
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

    // Utilisateur 1 achète 2 tickets et tente de redeem avant la fin
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

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 0, location = raffles)]
fun test_redeem_owner_game_already_completed() {
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
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // L'owner tente de redeem avant la fin
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 1, location = raffles)]
fun test_create_raffle_invalid_end_date() {
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

        // Essayer de créer une raffle avec une date de fin dans le passé
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            500, // date dans le passé (timestamp actuel = 1000)
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 2, location = raffles)]
fun test_create_raffle_invalid_reward_amount() {
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
        let reward_coin = coin::mint_for_testing<REWARD>(0, ctx(&mut scenario));

        // Essayer de créer une raffle avec une date de fin dans le passé
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin, // montant de récompense invalide (0)
            10,
            2000,
            2,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 3, location = raffles)]
fun test_invalid_ticket_configuration() {
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

        // min_tickets >= max_tickets (invalide)
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            5, // min = 5
            3, // max = 3 (invalide car < min)
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 4, location = raffles)]
fun test_zero_ticket_price() {
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

        // Prix de ticket = 0 (invalide)
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            0, // prix invalide
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 5, location = raffles)]
fun test_redeem_owner_failed_invalid_owner() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer l'état Random global
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

    // Créer et partager le registry
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
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

    // Acheter quelques tickets
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_ticket(&mut raffle, 2, payment_coin, &clock, ctx(&mut scenario));
        test::return_shared(raffle);
    };

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Vérifier que le statut change après la fin
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        // La raffle va fail car pas assez de participants et temps écoulé
        let participants = raffles::get_participants(&raffle);
        assert!(participants.length() < 5, 0); // moins que min_tickets

        let status_before = raffles::get_status(&raffle);
        assert!(status_before == 0, 1);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status_after = raffles::get_status(&raffle);
        assert!(status_after == 2, 2);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Nouvelle transaction avec USER1 comme sender, (fail car non owner)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = raffles)]
fun test_buy_ticket_after_end_date() {
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
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Avancer le temps après la date de fin
    clock::set_for_testing(&mut clock, 2500);

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        // Essayer d'acheter après la date de fin (devrait échouer)
        raffles::buy_ticket(&mut raffle, 2, payment_coin, &clock, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 6, location = raffles)]
fun test_buy_ticket_status_not_in_progress() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    let mut clock2 = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);
    clock::set_for_testing(&mut clock2, 1000);

    // Créer l'état Random global
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

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
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Avancer le temps après la date de fin
    clock::set_for_testing(&mut clock, 2500);

    // Vérifier que le statut change après la fin
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        let status_before = raffles::get_status(&raffle);
        assert!(status_before == 0, 0);

        raffles::determine_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status_after = raffles::get_status(&raffle);
        assert!(status_after == 2, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        // Essayer d'acheter en status failed (devrait échouer)
        raffles::buy_ticket(&mut raffle, 2, payment_coin, &clock2, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    clock::destroy_for_testing(clock2);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 7, location = raffles)]
fun test_buy_ticket_invalid_ticket_count() {
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
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(100, ctx(&mut scenario));

        // Essayer d'acheter 0 ticket (devrait échouer)
        raffles::buy_ticket(&mut raffle, 0, payment_coin, &clock, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 7, location = raffles)]
fun test_buy_ticket_invalid_payment_count() {
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
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(0, ctx(&mut scenario));

        // Essayer d'acheter 3 tickets (devrait échouer)
        raffles::buy_ticket(&mut raffle, 3, payment_coin, &clock, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 8, location = raffles)]
fun test_buy_ticket_insufficient_payment() {
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
            10, // prix par ticket = 10
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(15, ctx(&mut scenario)); // seulement 15 pour 2 tickets (20 requis)

        // Essayer d'acheter 2 tickets avec un paiement insuffisant
        raffles::buy_ticket(&mut raffle, 2, payment_coin, &clock, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 9, location = raffles)]
fun test_buy_ticket_exceeds_max() {
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
            10,
            2000,
            2,
            5, // max 5 tickets
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(60, ctx(&mut scenario));

        // Essayer d'acheter 6 tickets (dépasse le max de 5)
        raffles::buy_ticket(&mut raffle, 6, payment_coin, &clock, ctx(&mut scenario));

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 10, location = raffles)]
fun test_determine_winner_raffle_not_ready() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer l'état Random global
    next_tx(&mut scenario, @0x0);
    {
        random::create_for_testing(ctx(&mut scenario));
    };

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
            5,
            10,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Abort car ni le temps n'est écoulé ni le max de tickets atteint
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

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 11, location = raffles)]
fun test_create_raffle_reward_coin_not_whitelisted() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager un registry vide (pas de whitelist)
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Essayer de créer une raffle avec un coin non whitelisté
    next_tx(&mut scenario, ADMIN);

    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        // Devrait échouer car REWARD n'est pas dans la whitelist
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 11, location = raffles)]
fun test_create_raffle_payment_coin_not_whitelisted() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager un registry avec seulement REWARD whitelisté
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<REWARD, MOCK_USDT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Essayer de créer une raffle avec un payment coin non whitelisté
    next_tx(&mut scenario, ADMIN);
    {
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        // Devrait échouer car PAYMENT n'est pas dans la whitelist
        raffles::create_raffle<REWARD, PAYMENT>(
            &registry,
            &clock,
            reward_coin,
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
#[expected_failure(abort_code = 12, location = raffles)]
fun test_create_nft_raffle_nft_not_whitelisted() {
    let mut scenario = test::begin(ADMIN);
    let mut clock = clock::create_for_testing(ctx(&mut scenario));
    clock::set_for_testing(&mut clock, 1000);

    // Créer et partager un registry avec seulement PAYMENT whitelisté
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_test_registry<OTHER_MOCK_NFT, PAYMENT>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer une collection et mint un NFT
    let mut collection_cap = mock_nft::init_for_testing(ctx(&mut scenario));
    let test_nft = mock_nft::mint_for_testing(&mut collection_cap, ctx(&mut scenario));

    // Essayer de créer une NFT raffle avec un NFT non whitelisté
    next_tx(&mut scenario, ADMIN);
    {
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        // Devrait échouer car le NFT n'est pas dans la whitelist
        raffles::create_nft_raffle<MockNFT, PAYMENT>(
            &registry,
            &clock,
            test_nft,
            10,
            2000,
            2,
            5,
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    transfer::public_transfer(collection_cap, ADMIN);
    clock::destroy_for_testing(clock);
    test::end(scenario);
}
