module raffles::mock_usdc;

use sui::coin::{Self, TreasuryCap};
use sui::url::{Self, Url};

public struct MOCK_USDC has drop {}

fun init(witness: MOCK_USDC, ctx: &mut TxContext) {
    let (treasury_cap, metadata) = coin::create_currency<MOCK_USDC>(
        witness,
        6, // decimals (USDC a 6 décimales)
        b"USDC",
        b"USD Coin (Mock)",
        b"Mock version of USDC for testing purposes",
        option::some<Url>(
            url::new_unsafe_from_bytes(b"https://centre.io/images/usdc/usdc-icon-86074d9d49.png"),
        ),
        ctx,
    );

    // Transfer the treasury cap to the publisher
    transfer::public_transfer(treasury_cap, tx_context::sender(ctx));

    // Freeze the metadata object
    transfer::public_freeze_object(metadata);
}

entry fun mint(
    treasury_cap: &mut TreasuryCap<MOCK_USDC>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    coin::mint_and_transfer(treasury_cap, amount, recipient, ctx);
}

entry fun burn(treasury_cap: &mut TreasuryCap<MOCK_USDC>, coin: coin::Coin<MOCK_USDC>) {
    coin::burn(treasury_cap, coin);
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext): TreasuryCap<MOCK_USDC> {
    let (treasury_cap, metadata) = coin::create_currency<MOCK_USDC>(
        MOCK_USDC {},
        6,
        b"USDC",
        b"USD Coin (Mock)",
        b"Mock version of USDC for testing purposes",
        option::none(),
        ctx,
    );
    transfer::public_freeze_object(metadata);
    treasury_cap
}
