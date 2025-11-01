#[test_only]
module raffles::whitelist_tests;

use raffles::mock_nft::MockNFT;
use raffles::raffles::{Self, WhitelistRegistry};
use std::string;
use std::type_name;
use sui::test_scenario::{Self as test, next_tx, ctx};

public struct MOCK_COIN has drop {}
public struct ANOTHER_COIN has drop {}

const ADMIN: address = @0xABBA;

#[test]
fun test_add_coin_to_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter un coin à la whitelist
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        // Obtenir le nom du type de MOCK_COIN
        let coin_type_name = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str = string::utf8(*coin_type_name.into_string().as_bytes());

        assert!(raffles::get_whitelisted_coins(&registry).length() == 0, 0);
        assert!(!raffles::is_coin_whitelisted(&registry, coin_type_str), 1);

        // Ajouter le coin à la whitelist
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 2);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_add_multiple_coins_to_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter plusieurs coins à la whitelist
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        // Ajouter MOCK_COIN
        let coin_type_name1 = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str1 = string::utf8(*coin_type_name1.into_string().as_bytes());
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str1);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 0);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str1), 1);

        // Ajouter ANOTHER_COIN
        let coin_type_name2 = type_name::with_original_ids<ANOTHER_COIN>();
        let coin_type_str2 = string::utf8(*coin_type_name2.into_string().as_bytes());
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str2);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 2, 2);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str2), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_add_duplicate_coin_to_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter le même coin deux fois (ne devrait pas créer de doublon)
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let coin_type_name = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str = string::utf8(*coin_type_name.into_string().as_bytes());

        // Vérifier que la whitelist est vide au départ
        assert!(raffles::get_whitelisted_coins(&registry).length() == 0, 0);

        // Ajouter une première fois
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str);

        // Vérifier qu'il y a maintenant 1 coin
        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 1);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str), 2);

        // Ajouter une deuxième fois (devrait être ignoré)
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str);

        // Vérifier qu'il y a toujours 1 coin (pas de doublon)
        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_remove_coin_from_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter puis retirer un coin
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let coin_type_name = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str = string::utf8(*coin_type_name.into_string().as_bytes());

        // Ajouter
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 0);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str), 1);

        // Retirer
        raffles::remove_coin_from_whitelist(&admin_cap, &mut registry, coin_type_str);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 0, 2);
        assert!(!raffles::is_coin_whitelisted(&registry, coin_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_remove_nonexistent_coin_from_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Essayer de retirer un coin qui n'existe pas (ne devrait pas causer d'erreur)
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let coin_type_name = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str = string::utf8(*coin_type_name.into_string().as_bytes());

        assert!(raffles::get_whitelisted_coins(&registry).length() == 0, 0);
        assert!(!raffles::is_coin_whitelisted(&registry, coin_type_str), 1);

        // Retirer sans avoir ajouté
        raffles::remove_coin_from_whitelist(&admin_cap, &mut registry, coin_type_str);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 0, 2);
        assert!(!raffles::is_coin_whitelisted(&registry, coin_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_add_nft_to_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter un NFT à la whitelist
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let nft_type_name = type_name::with_original_ids<MockNFT>();
        let nft_type_str = string::utf8(*nft_type_name.into_string().as_bytes());

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 0, 0);
        assert!(!raffles::is_nft_whitelisted(&registry, nft_type_str), 1);

        raffles::add_nft_to_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 1, 2);
        assert!(raffles::is_nft_whitelisted(&registry, nft_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_add_duplicate_nft_to_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter le même NFT deux fois
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let nft_type_name = type_name::with_original_ids<MockNFT>();
        let nft_type_str = string::utf8(*nft_type_name.into_string().as_bytes());

        // Ajouter une première fois
        raffles::add_nft_to_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 1, 0);
        assert!(raffles::is_nft_whitelisted(&registry, nft_type_str), 1);

        // Ajouter une deuxième fois (devrait être ignoré)
        raffles::add_nft_to_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 1, 2);
        assert!(raffles::is_nft_whitelisted(&registry, nft_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_remove_nft_from_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Ajouter puis retirer un NFT
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let nft_type_name = type_name::with_original_ids<MockNFT>();
        let nft_type_str = string::utf8(*nft_type_name.into_string().as_bytes());

        // Ajouter
        raffles::add_nft_to_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 1, 0);
        assert!(raffles::is_nft_whitelisted(&registry, nft_type_str), 1);

        // Retirer
        raffles::remove_nft_from_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 0, 2);
        assert!(!raffles::is_nft_whitelisted(&registry, nft_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_remove_nonexistent_nft_from_whitelist_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Essayer de retirer un NFT qui n'existe pas
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        let nft_type_name = type_name::with_original_ids<MockNFT>();
        let nft_type_str = string::utf8(*nft_type_name.into_string().as_bytes());

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 0, 0);
        assert!(!raffles::is_nft_whitelisted(&registry, nft_type_str), 1);

        // Retirer sans avoir ajouté
        raffles::remove_nft_from_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_nfts(&registry).length() == 0, 2);
        assert!(!raffles::is_nft_whitelisted(&registry, nft_type_str), 3);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}

#[test]
fun test_mixed_coin_and_nft_whitelist_operations_success() {
    let mut scenario = test::begin(ADMIN);

    // Créer un registry vide
    next_tx(&mut scenario, ADMIN);
    {
        let _registry_id = raffles::create_and_share_empty_registry(ctx(&mut scenario));
    };

    // Opérations mixtes coins et NFTs
    next_tx(&mut scenario, ADMIN);
    {
        let admin_cap = raffles::create_test_admin_cap(ctx(&mut scenario));
        let mut registry = test::take_shared<WhitelistRegistry>(&scenario);

        // Ajouter des coins
        let coin_type_name1 = type_name::with_original_ids<MOCK_COIN>();
        let coin_type_str1 = string::utf8(*coin_type_name1.into_string().as_bytes());
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str1);

        let coin_type_name2 = type_name::with_original_ids<ANOTHER_COIN>();
        let coin_type_str2 = string::utf8(*coin_type_name2.into_string().as_bytes());
        raffles::add_coin_to_whitelist(&admin_cap, &mut registry, coin_type_str2);

        // Ajouter un NFT
        let nft_type_name = type_name::with_original_ids<MockNFT>();
        let nft_type_str = string::utf8(*nft_type_name.into_string().as_bytes());
        raffles::add_nft_to_whitelist(&admin_cap, &mut registry, nft_type_str);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 2, 0);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str1), 1);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str2), 1);
        assert!(raffles::get_whitelisted_nfts(&registry).length() == 1, 3);
        assert!(raffles::is_nft_whitelisted(&registry, nft_type_str), 4);

        // Retirer un coin
        raffles::remove_coin_from_whitelist(&admin_cap, &mut registry, coin_type_str2);

        assert!(raffles::get_whitelisted_coins(&registry).length() == 1, 5);
        assert!(raffles::is_coin_whitelisted(&registry, coin_type_str1), 6);
        assert!(!raffles::is_coin_whitelisted(&registry, coin_type_str2), 7);

        transfer::public_transfer(admin_cap, ADMIN);
        test::return_shared(registry);
    };

    test::end(scenario);
}
