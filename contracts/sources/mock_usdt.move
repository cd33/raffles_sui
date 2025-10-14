module raffles::mock_usdt;

use sui::coin::{Self, TreasuryCap};
use sui::url::{Self, Url};

public struct MOCK_USDT has drop {}

fun init(witness: MOCK_USDT, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency<MOCK_USDT>(
        witness,
        6, // decimals (USDT a 6 décimales)
        b"USDT",
        b"Tether USD (Mock)",
        b"Mock version of USDT for testing purposes",
        option::some<Url>(
            url::new_unsafe_from_bytes(b"https://tether.to/images/logoMarkGreen.png"),
        ),
        ctx,
    );

    // Transfer the treasury cap to the publisher
    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

    // Freeze the metadata object
    transfer::public_freeze_object(metadata);
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
    let (treasury_cap, metadata) = coin::create_currency<MOCK_USDT>(
        MOCK_USDT {},
        6,
        b"USDT",
        b"Tether USD (Mock)",
        b"Mock version of USDT for testing purposes",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    treasury_cap
}
