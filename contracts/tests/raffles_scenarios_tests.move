#[test_only]
module raffles::raffles_scenarios_tests;

use raffles::mock_nft::{Self, MockNFT};
use raffles::raffles::{Self, Raffle, NFTRaffle};
use sui::balance;
use sui::clock;
use sui::coin::{Self, Coin};
use sui::random::{Self, Random};
use sui::test_scenario::{Self as test, next_tx, ctx};

public struct REWARD has drop {}
public struct PAYMENT has drop {}

const ADMIN: address = @0xABBA;
const USER1: address = @0x1234;

#[test]
fun test_double_redeem_scenario_success() {
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
            10, // prix du ticket
            2000, // date de fin
            2, // min tickets
            10, // max tickets
            ctx(&mut scenario),
        );

        test::return_shared(registry);
    };

    // Utilisateur achète 2 tickets
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

    // Déterminer le gagnant
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

    // Premier redeem du gagnant (USER1) - doit fonctionner
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 2);

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 3); // Balance vidé

        test::return_shared(raffle);
    };

    // Vérifier que le coin a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);
        assert!(coin::value(&transferred_coin) == 1000, 4);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de redeem du gagnant - ne doit rien faire (balance déjà vide)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 0, 5); // Déjà vide

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 6); // Toujours vide

        test::return_shared(raffle);
    };

    // Premier redeem du owner (ADMIN) - doit fonctionner
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 20, 7); // Paiements des tickets

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 8); // Balance vidé

        test::return_shared(raffle);
    };

    // Vérifier que le coin a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        let transferred_coin = test::take_from_sender<Coin<PAYMENT>>(&scenario);
        assert!(coin::value(&transferred_coin) == 20, 9);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de redeem du owner - ne doit rien faire (balance déjà vide)
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, PAYMENT>>(&scenario);

        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 0, 10); // Déjà vide

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 11); // Toujours vide

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_double_redeem_failed_scenario_success() {
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
        let _registry_id = raffles::create_and_share_test_registry<REWARD, REWARD>(
            false,
            ctx(&mut scenario),
        );
    };

    // Créer la raffle avec un minimum élevé pour qu'elle échoue
    next_tx(&mut scenario, ADMIN);
    {
        // Test avec REWARD pour les deux tokens pour simplifier
        let reward_coin = coin::mint_for_testing<REWARD>(1000, ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);

        raffles::create_raffle<REWARD, REWARD>(
            &registry,
            &clock,
            reward_coin,
            200, // prix du ticket élevé
            2000, // date de fin
            6, // min tickets élevé
            10, // max tickets
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur achète seulement 2 tickets (insuffisant pour le minimum)
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

    // Avancer le temps pour que la raffle se termine
    clock::set_for_testing(&mut clock, 2500);

    // Déterminer que la raffle a échoué
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
        assert!(winner == @0x0, 1); // Pas de gagnant

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Premier remboursement de USER1 - doit fonctionner
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 400, 2); // Paiements de USER1

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 3); // USER1 remboursé

        test::return_shared(raffle);
    };

    // Vérifier que le remboursement a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);
        assert!(coin::value(&transferred_coin) == 400, 4);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de remboursement de USER1 - ne doit rien faire
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let balance_before = raffles::get_balance(&raffle);
        assert!(balance::value(balance_before) == 0, 5); // Plus rien à rembourser

        raffles::redeem(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 6); // Toujours vide

        test::return_shared(raffle);
    };

    // Premier redeem du owner (récupération de la récompense car raffle échouée)
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 1000, 7); // Récompense initiale

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 8); // Récompense récupérée

        test::return_shared(raffle);
    };

    // Vérifier que la récompense a été transférée à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        let transferred_coin = test::take_from_sender<Coin<REWARD>>(&scenario);
        assert!(coin::value(&transferred_coin) == 1000, 9);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de redeem du owner - ne doit rien faire
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<Raffle<REWARD, REWARD>>(&scenario);

        let reward_before = raffles::get_reward(&raffle);
        assert!(balance::value(reward_before) == 0, 10); // Déjà récupéré

        raffles::redeem_owner(&mut raffle, ctx(&mut scenario));

        let reward_after = raffles::get_reward(&raffle);
        assert!(balance::value(reward_after) == 0, 11); // Toujours vide

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

// Helper function pour créer un NFT de test
#[test_only]
fun create_mock_nft(ctx: &mut TxContext): MockNFT {
    let mut collection_cap = mock_nft::init_for_testing(ctx);
    let nft = mock_nft::mint_for_testing(&mut collection_cap, ctx);
    mock_nft::destroy_for_testing(collection_cap);
    nft
}

#[test]
fun test_nft_double_redeem_scenario_success() {
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
        let _registry_id = raffles::create_and_share_test_registry<MockNFT, PAYMENT>(
            true,
            ctx(&mut scenario),
        );
    };

    // Créer la NFT raffle
    next_tx(&mut scenario, ADMIN);
    {
        let nft = create_mock_nft(ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_nft_raffle<MockNFT, PAYMENT>(
            &registry,
            &clock,
            nft,
            10, // prix du ticket
            2000, // date de fin
            2, // min tickets
            10, // max tickets
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur achète 2 tickets
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(20, ctx(&mut scenario));

        raffles::buy_nft_ticket(
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

    // Déterminer le gagnant
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        raffles::determine_nft_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status = raffles::get_nft_status(&raffle);
        assert!(status == 1, 0); // COMPLETED
        let winner = raffles::get_nft_winner(&raffle);
        assert!(winner == USER1, 1);

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Premier redeem du gagnant (USER1) - doit fonctionner
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let has_nft_before = raffles::has_nft_reward(&raffle);
        assert!(has_nft_before == true, 2); // NFT présent

        raffles::redeem_nft(&mut raffle, ctx(&mut scenario));

        let has_nft_after = raffles::has_nft_reward(&raffle);
        assert!(has_nft_after == false, 3); // NFT transféré

        test::return_shared(raffle);
    };

    // Vérifier que le NFT a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        let transferred_nft = test::take_from_sender<MockNFT>(&scenario);
        assert!(mock_nft::serial_number(&transferred_nft) == 1, 4);
        test::return_to_sender(&scenario, transferred_nft);
    };

    // Deuxième tentative de redeem du gagnant - ne doit rien faire (NFT déjà transféré)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let has_nft_before = raffles::has_nft_reward(&raffle);
        assert!(has_nft_before == false, 5); // Plus de NFT

        raffles::redeem_nft(&mut raffle, ctx(&mut scenario));

        let has_nft_after = raffles::has_nft_reward(&raffle);
        assert!(has_nft_after == false, 6); // Toujours pas de NFT

        test::return_shared(raffle);
    };

    // Premier redeem du owner (ADMIN) - doit fonctionner
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let balance_before = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_before) == 20, 7); // Paiements des tickets

        raffles::redeem_nft_owner(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 8); // Balance vidé

        test::return_shared(raffle);
    };

    // Vérifier que le coin a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        let transferred_coin = test::take_from_sender<Coin<PAYMENT>>(&scenario);
        assert!(coin::value(&transferred_coin) == 20, 9);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de redeem du owner - ne doit rien faire (balance déjà vide)
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let balance_before = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_before) == 0, 10); // Déjà vide

        raffles::redeem_nft_owner(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 11); // Toujours vide

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}

#[test]
fun test_nft_double_redeem_failed_scenario_success() {
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
        let _registry_id = raffles::create_and_share_test_registry<MockNFT, PAYMENT>(
            true,
            ctx(&mut scenario),
        );
    };

    // Créer la NFT raffle avec un minimum élevé pour qu'elle échoue
    next_tx(&mut scenario, ADMIN);
    {
        let nft = create_mock_nft(ctx(&mut scenario));
        let registry = test::take_shared<raffles::WhitelistRegistry>(&scenario);
        raffles::create_nft_raffle<MockNFT, PAYMENT>(
            &registry,
            &clock,
            nft,
            200, // prix du ticket élevé
            2000, // date de fin
            6, // min tickets élevé
            10, // max tickets
            ctx(&mut scenario),
        );
        test::return_shared(registry);
    };

    // Utilisateur achète seulement 2 tickets (insuffisant pour le minimum)
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);
        let payment_coin = coin::mint_for_testing<PAYMENT>(400, ctx(&mut scenario));

        raffles::buy_nft_ticket(
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

    // Déterminer que la raffle a échoué
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);
        let random_state = test::take_shared<Random>(&scenario);

        raffles::determine_nft_winner(
            &mut raffle,
            &random_state,
            &clock,
            ctx(&mut scenario),
        );

        let status = raffles::get_nft_status(&raffle);
        assert!(status == 2, 0); // FAILED
        let winner = raffles::get_nft_winner(&raffle);
        assert!(winner == @0x0, 1); // Pas de gagnant

        test::return_shared(random_state);
        test::return_shared(raffle);
    };

    // Premier remboursement de USER1 - doit fonctionner
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let balance_before = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_before) == 400, 2); // Paiements de USER1

        raffles::redeem_nft(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 3); // USER1 remboursé

        test::return_shared(raffle);
    };

    // Vérifier que le remboursement a été transféré à USER1
    next_tx(&mut scenario, USER1);
    {
        let transferred_coin = test::take_from_sender<Coin<PAYMENT>>(&scenario);
        assert!(coin::value(&transferred_coin) == 400, 4);
        test::return_to_sender(&scenario, transferred_coin);
    };

    // Deuxième tentative de remboursement de USER1 - ne doit rien faire
    next_tx(&mut scenario, USER1);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let balance_before = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_before) == 0, 5); // Plus rien à rembourser

        raffles::redeem_nft(&mut raffle, ctx(&mut scenario));

        let balance_after = raffles::get_nft_balance(&raffle);
        assert!(balance::value(balance_after) == 0, 6); // Toujours vide

        test::return_shared(raffle);
    };

    // Premier redeem du owner (récupération du NFT car raffle échouée)
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let has_nft_before = raffles::has_nft_reward(&raffle);
        assert!(has_nft_before == true, 7); // NFT toujours présent

        raffles::redeem_nft_owner(&mut raffle, ctx(&mut scenario));

        let has_nft_after = raffles::has_nft_reward(&raffle);
        assert!(has_nft_after == false, 8); // NFT récupéré

        test::return_shared(raffle);
    };

    // Vérifier que le NFT a été transféré à ADMIN
    next_tx(&mut scenario, ADMIN);
    {
        let transferred_nft = test::take_from_sender<MockNFT>(&scenario);
        assert!(mock_nft::serial_number(&transferred_nft) == 1, 9);
        test::return_to_sender(&scenario, transferred_nft);
    };

    // Deuxième tentative de redeem du owner - ne doit rien faire
    next_tx(&mut scenario, ADMIN);
    {
        let mut raffle = test::take_shared<NFTRaffle<MockNFT, PAYMENT>>(&scenario);

        let has_nft_before = raffles::has_nft_reward(&raffle);
        assert!(has_nft_before == false, 10); // Plus de NFT

        raffles::redeem_nft_owner(&mut raffle, ctx(&mut scenario));

        let has_nft_after = raffles::has_nft_reward(&raffle);
        assert!(has_nft_after == false, 11); // Toujours pas de NFT

        test::return_shared(raffle);
    };

    clock::destroy_for_testing(clock);
    test::end(scenario);
}
