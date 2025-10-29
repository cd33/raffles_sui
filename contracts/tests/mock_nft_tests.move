#[test_only]
module raffles::mock_nft_tests;

use raffles::mock_nft;
use std::string;
use sui::test_scenario;

const CREATOR: address = @0x1;
const USER1: address = @0x2;
const USER2: address = @0x3;

#[test]
fun test_mint_nft() {
    let mut scenario = test_scenario::begin(CREATOR);

    // Initialiser la collection
    let mut collection_cap = mock_nft::init_for_testing(scenario.ctx());

    // Mint un NFT pour USER1
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER1,
        scenario.ctx(),
    );

    // Vérifier que le total_minted a augmenté
    assert!(mock_nft::total_minted(&collection_cap) == 1, 0);

    // Nettoyer
    mock_nft::destroy_for_testing(collection_cap);
    scenario.end();
}

#[test]
fun test_nft_properties() {
    let mut scenario = test_scenario::begin(CREATOR);

    // Initialiser la collection
    let mut collection_cap = mock_nft::init_for_testing(scenario.ctx());

    // Mint un NFT pour les tests
    let nft = mock_nft::mint_for_testing(&mut collection_cap, scenario.ctx());

    // Vérifier les propriétés
    assert!(mock_nft::name(&nft) == &string::utf8(b"Test NFT"), 0);
    assert!(mock_nft::description(&nft) == &string::utf8(b"A test NFT"), 1);
    assert!(mock_nft::creator(&nft) == CREATOR, 2);
    assert!(mock_nft::serial_number(&nft) == 1, 3);

    // Brûler le NFT
    mock_nft::burn_nft(nft);

    mock_nft::destroy_for_testing(collection_cap);
    scenario.end();
}

#[test]
fun test_max_supply_limit() {
    let mut scenario = test_scenario::begin(CREATOR);

    // Créer une collection avec une limite faible pour le test
    let mut collection_cap = mock_nft::init_with_params_for_testing(
        9999, // Presque à la limite
        10000,
        CREATOR,
        scenario.ctx(),
    );

    // Mint un dernier NFT (devrait fonctionner)
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER1,
        scenario.ctx(),
    );

    // Vérifier qu'on a atteint la limite
    assert!(mock_nft::total_minted(&collection_cap) == 10000, 0);

    mock_nft::destroy_for_testing(collection_cap);
    scenario.end();
}

#[test]
#[expected_failure(abort_code = raffles::mock_nft::EMaxSupplyReached)]
fun test_max_supply_exceeded() {
    let mut scenario = test_scenario::begin(CREATOR);

    // Créer une collection déjà à la limite
    let mut collection_cap = mock_nft::init_with_params_for_testing(
        10000,
        10000,
        CREATOR,
        scenario.ctx(),
    );

    // Essayer de mint un NFT supplémentaire (devrait échouer)
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER1,
        scenario.ctx(),
    );

    mock_nft::destroy_for_testing(collection_cap);
    scenario.end();
}

#[test]
fun test_multiple_users() {
    let mut scenario = test_scenario::begin(CREATOR);

    let mut collection_cap = mock_nft::init_for_testing(scenario.ctx());

    // Mint des NFTs pour différents utilisateurs
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT 1"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER1,
        scenario.ctx(),
    );
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT 2"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER2,
        scenario.ctx(),
    );
    mock_nft::mint_nft(
        &mut collection_cap,
        string::utf8(b"Test NFT 3"),
        string::utf8(b"A test NFT"),
        string::utf8(b"https://example.com/image.png"),
        string::utf8(b"{\"trait\":\"test\"}"),
        USER1,
        scenario.ctx(),
    );

    // Vérifier le total
    assert!(mock_nft::total_minted(&collection_cap) == 3, 0);

    mock_nft::destroy_for_testing(collection_cap);
    scenario.end();
}
