module raffles::mock_usdt;

use std::string;
use sui::coin::{Self, TreasuryCap};
use sui::coin_registry;

public struct MOCK_USDT has drop {}

fun init(witness: MOCK_USDT, ctx: &mut TxContext) {
    let (init, treasury_cap) = coin_registry::new_currency_with_otw<MOCK_USDT>(
        witness,
        6, // decimals (USDT a 6 décimales)
        string::utf8(b"USDT"),
        string::utf8(b"Tether USD (Mock)"),
        string::utf8(b"Mock version of USDT for testing purposes"),
        string::utf8(b"https://tether.to/images/logoMarkGreen.png"),
        ctx,
    );

    // Finalise la création et obtient le MetadataCap
    let metadata_cap = coin_registry::finalize(init, ctx);

    // Transfer the treasury cap and metadata cap to the publisher
    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    transfer::public_transfer(metadata_cap, tx_context::sender(ctx));
}

entry fun mint(
    treasury_cap: &mut TreasuryCap<MOCK_USDT>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
}

entry fun burn(treasury_cap: &mut TreasuryCap<MOCK_USDT>, coin: coin::Coin<MOCK_USDT>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): TreasuryCap<MOCK_USDT> {
    let (init, treasury_cap) = coin_registry::new_currency_with_otw<MOCK_USDT>(
        MOCK_USDT {},
        6,
        string::utf8(b"USDT"),
        string::utf8(b"Tether USD (Mock)"),
        string::utf8(b"Mock version of USDT for testing purposes"),
        string::utf8(b""),
        ctx,
    );

    // Finalise et détruit le MetadataCap car on ne l'utilise pas dans les tests
    let metadata_cap = coin_registry::finalize(init, ctx);
    sui::test_utils::destroy(metadata_cap);

    treasury_cap
}
