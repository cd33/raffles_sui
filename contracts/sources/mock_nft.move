module raffles::mock_nft;

use std::string::{Self, String};
use sui::display;
use sui::package;
use sui::url::{Self, Url};

/// Code d'erreur pour quand la limite maximale est atteinte
const EMaxSupplyReached: u64 = 0;

/// Structure représentant notre NFT mock
public struct MockNFT has key, store {
    id: UID,
    name: String,
    description: String,
    image_url: Url,
    attributes: String, // JSON string pour les attributs
    creator: address,
    serial_number: u64,
}

/// One-time witness pour le module
public struct MOCK_NFT has drop {}

/// Structure pour gérer la collection
public struct CollectionCap has key, store {
    id: UID,
    total_minted: u64,
    max_supply: u64,
    creator: address,
}

/// Initialisation du module
fun init(otw: MOCK_NFT, ctx: &mut TxContext) {
    let keys = vector[
        string::utf8(b"name"),
        string::utf8(b"description"),
        string::utf8(b"image_url"),
        string::utf8(b"attributes"),
        string::utf8(b"creator"),
        string::utf8(b"serial_number"),
    ];

    let values = vector[
        string::utf8(b"{name}"),
        string::utf8(b"{description}"),
        string::utf8(b"{image_url}"),
        string::utf8(b"{attributes}"),
        string::utf8(b"{creator}"),
        string::utf8(b"#{serial_number}"),
    ];

    // Créer le package publisher
    let publisher = package::claim(otw, ctx);

    // Créer l'objet Display pour les métadonnées
    let mut display = display::new_with_fields<MockNFT>(
        &publisher,
        keys,
        values,
        ctx,
    );

    display.update_version();

    // Créer le CollectionCap avec une limite de 10000 NFTs
    let collection_cap = CollectionCap {
        id: object::new(ctx),
        total_minted: 0,
        max_supply: 10000,
        creator: tx_context::sender(ctx),
    };

    // Transférer les objets
    transfer::public_transfer(publisher, tx_context::sender(ctx));
    transfer::public_transfer(display, tx_context::sender(ctx));
    transfer::public_transfer(collection_cap, tx_context::sender(ctx));
}

/// Fonction pour minter un nouveau NFT
entry fun mint_nft(
    collection_cap: &mut CollectionCap,
    name: String,
    description: String,
    image_url: String,
    attributes: String,
    recipient: address,
    ctx: &mut TxContext,
) {
    // Vérifier qu'on n'a pas atteint la limite
    assert!(collection_cap.total_minted < collection_cap.max_supply, EMaxSupplyReached);

    // Incrémenter le compteur
    collection_cap.total_minted = collection_cap.total_minted + 1;

    // Créer le NFT
    let nft = MockNFT {
        id: object::new(ctx),
        name,
        description,
        image_url: url::new_unsafe_from_bytes(*string::as_bytes(&image_url)),
        attributes,
        creator: collection_cap.creator,
        serial_number: collection_cap.total_minted,
    };

    // Transférer le NFT au destinataire
    transfer::public_transfer(nft, recipient);
}

/// Fonction pour brûler un NFT
entry fun burn_nft(nft: MockNFT) {
    let MockNFT {
        id,
        name: _,
        description: _,
        image_url: _,
        attributes: _,
        creator: _,
        serial_number: _,
    } = nft;
    id.delete();
}

/// Fonctions getter publiques
public fun name(nft: &MockNFT): &String {
    &nft.name
}

public fun description(nft: &MockNFT): &String {
    &nft.description
}

public fun image_url(nft: &MockNFT): &Url {
    &nft.image_url
}

public fun attributes(nft: &MockNFT): &String {
    &nft.attributes
}

public fun creator(nft: &MockNFT): address {
    nft.creator
}

public fun serial_number(nft: &MockNFT): u64 {
    nft.serial_number
}

public fun total_minted(collection_cap: &CollectionCap): u64 {
    collection_cap.total_minted
}

public fun max_supply(collection_cap: &CollectionCap): u64 {
    collection_cap.max_supply
}

// ======== Fonctions de test ========

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): CollectionCap {
    CollectionCap {
        id: object::new(ctx),
        total_minted: 0,
        max_supply: 10000,
        creator: tx_context::sender(ctx),
    }
}

#[test_only]
public fun init_with_params_for_testing(
    total_minted: u64,
    max_supply: u64,
    creator: address,
    ctx: &mut TxContext,
): CollectionCap {
    CollectionCap {
        id: object::new(ctx),
        total_minted,
        max_supply,
        creator,
    }
}

#[test_only]
public fun destroy_for_testing(collection_cap: CollectionCap) {
    let CollectionCap { id, total_minted: _, max_supply: _, creator: _ } = collection_cap;
    object::delete(id);
}

#[test_only]
public fun mint_for_testing(collection_cap: &mut CollectionCap, ctx: &mut TxContext): MockNFT {
    collection_cap.total_minted = collection_cap.total_minted + 1;

    MockNFT {
        id: object::new(ctx),
        name: string::utf8(b"Test NFT"),
        description: string::utf8(b"A test NFT"),
        image_url: url::new_unsafe_from_bytes(b"https://test.com/image.png"),
        attributes: string::utf8(b"{\"test\":\"true\"}"),
        creator: collection_cap.creator,
        serial_number: collection_cap.total_minted,
    }
}
