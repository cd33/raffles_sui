module raffles::raffles;

use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::Random;
use sui::tx_context::sender;

// === ERROR CODES ===
/// Game/Raffle Status Errors
const EGameAlreadyCompleted: u64 = 0;
const ERaffleNotReady: u64 = 10;
/// Creation/Configuration Errors
const EInvalidEndDate: u64 = 1;
const EInvalidRewardAmount: u64 = 2;
const EInvalidTicketConfiguration: u64 = 3;
const EInvalidTicketPrice: u64 = 4;
/// Purchase/Payment Errors
const ERaffleExpired: u64 = 6;
const EInvalidTicketCount: u64 = 7;
const EInsufficientPayment: u64 = 8;
const EExceedsMaxTickets: u64 = 9;
/// Authorization Errors
const EInvalidOwner: u64 = 5;

// === RAFFLE STATUSES ===
const IN_PROGRESS: u8 = 0;
const COMPLETED: u8 = 1;
const FAILED: u8 = 2;

// === EVENTS ===
public struct RaffleCreated has copy, drop { id: object::ID }
public struct NFTRaffleCreated has copy, drop { id: object::ID }

// === ADMIN CAP ===
public struct AdminCap has key, store { id: UID }

// === STRUCTURES ===
/// Standard raffle with a coin reward
public struct Raffle<phantom Reward, phantom Payment> has key {
    id: UID,
    reward: Balance<Reward>,
    owner: address,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    participants: vector<address>,
    balance: Balance<Payment>,
    winner: address,
    status: u8,
}

/// Raffle for an NFT reward, T represents the type of NFT (must have key + store)
public struct NFTRaffle<T: key + store, phantom Payment> has key {
    id: UID,
    reward: option::Option<T>,
    owner: address,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    participants: vector<address>,
    balance: Balance<Payment>,
    winner: address,
    status: u8,
}

// === INIT FUNCTION ===
fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender())
}

// === RAFFLE CREATION ===
public fun create_raffle<Reward, Payment>(
    clock: &Clock,
    reward: Coin<Reward>,
    ticket_price: u64,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    validate_raffle_config(end_date, clock.timestamp_ms(), min_tickets, max_tickets, ticket_price);
    assert!(coin::value(&reward) > 0, EInvalidRewardAmount);

    let raffle = Raffle {
        id: object::new(ctx),
        reward: coin::into_balance<Reward>(reward),
        owner: ctx.sender(),
        end_date,
        min_tickets,
        max_tickets,
        ticket_price,
        participants: vector::empty(),
        balance: balance::zero<Payment>(),
        winner: @0x0,
        status: IN_PROGRESS,
    };

    event::emit(RaffleCreated { id: object::uid_to_inner(&raffle.id) });

    transfer::share_object(raffle);
}

public fun create_nft_raffle<T: key + store, Payment>(
    clock: &Clock,
    reward_nft: T,
    ticket_price: u64,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    validate_raffle_config(end_date, clock.timestamp_ms(), min_tickets, max_tickets, ticket_price);

    let raffle = NFTRaffle {
        id: object::new(ctx),
        reward: option::some(reward_nft),
        owner: ctx.sender(),
        end_date,
        min_tickets,
        max_tickets,
        ticket_price,
        participants: vector::empty(),
        balance: balance::zero<Payment>(),
        winner: @0x0,
        status: IN_PROGRESS,
    };

    event::emit(NFTRaffleCreated { id: object::uid_to_inner(&raffle.id) });

    transfer::share_object(raffle);
}

// === TICKET PURCHASE ===
public fun buy_ticket<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    amount_tickets: u64,
    payment: Coin<Payment>,
    clock: &Clock,
    ctx: &TxContext,
) {
    handle_ticket_purchase(
        &mut raffle.participants,
        &mut raffle.balance,
        payment,
        amount_tickets,
        raffle.ticket_price,
        raffle.max_tickets,
        clock,
        raffle.end_date,
        raffle.status,
        ctx,
    );
}

public fun buy_nft_ticket<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    amount_tickets: u64,
    payment: Coin<Payment>,
    clock: &Clock,
    ctx: &TxContext,
) {
    handle_ticket_purchase(
        &mut raffle.participants,
        &mut raffle.balance,
        payment,
        amount_tickets,
        raffle.ticket_price,
        raffle.max_tickets,
        clock,
        raffle.end_date,
        raffle.status,
        ctx,
    );
}

// === WINNER SELECTION ===
entry fun determine_winner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    r: &Random,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (status, winner) = pick_winner(
        &raffle.participants,
        raffle.min_tickets,
        raffle.max_tickets,
        raffle.end_date,
        raffle.status,
        clock,
        r,
        ctx,
    );
    raffle.status = status;
    raffle.winner = winner;
}

entry fun determine_nft_winner<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    r: &Random,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (status, winner) = pick_winner(
        &raffle.participants,
        raffle.min_tickets,
        raffle.max_tickets,
        raffle.end_date,
        raffle.status,
        clock,
        r,
        ctx,
    );
    raffle.status = status;
    raffle.winner = winner;
}

// === REDEEM FUNCTIONS ===
#[allow(lint(self_transfer))]
public fun redeem<Reward, Payment>(raffle: &mut Raffle<Reward, Payment>, ctx: &mut TxContext) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    if (raffle.status == FAILED) {
        refund_participant(&mut raffle.participants, &mut raffle.balance, raffle.ticket_price, ctx);
    } else if (raffle.reward.value() > 0) {
        let refund = coin::from_balance(raffle.reward.withdraw_all(), ctx);
        transfer::public_transfer(refund, raffle.winner);
    };
}

#[allow(lint(self_transfer))]
public fun redeem_nft<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);

    if (raffle.status == FAILED) {
        refund_participant(&mut raffle.participants, &mut raffle.balance, raffle.ticket_price, ctx);
    } else {
        assert!(ctx.sender() == raffle.winner, EInvalidOwner);
        if (option::is_some(&raffle.reward)) {
            let nft = option::extract(&mut raffle.reward);
            transfer::public_transfer(nft, raffle.winner);
        };
    }
}

public fun redeem_owner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);

    if (raffle.status == FAILED) {
        let refund = coin::from_balance(raffle.reward.withdraw_all(), ctx);
        transfer::public_transfer(refund, raffle.owner);
    } else if (raffle.balance.value() > 0) {
        let refund = coin::from_balance(raffle.balance.withdraw_all(), ctx);
        transfer::public_transfer(refund, raffle.owner);
    }
}

public fun redeem_nft_owner<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);

    if (raffle.status == FAILED) {
        if (option::is_some(&raffle.reward)) {
            let nft = option::extract(&mut raffle.reward);
            transfer::public_transfer(nft, raffle.owner);
        };
    } else if (raffle.balance.value() > 0) {
        let payment = coin::from_balance(raffle.balance.withdraw_all(), ctx);
        transfer::public_transfer(payment, raffle.owner);
    }
}

// === COMMON UTILITIES ===
fun validate_raffle_config(
    end_date: u64,
    now: u64,
    min_tickets: u64,
    max_tickets: u64,
    price: u64,
) {
    assert!(end_date > now, EInvalidEndDate);
    assert!(min_tickets < max_tickets, EInvalidTicketConfiguration);
    assert!(price > 0, EInvalidTicketPrice);
}

fun handle_ticket_purchase<Payment>(
    participants: &mut vector<address>,
    balance: &mut Balance<Payment>,
    payment: Coin<Payment>,
    amount_tickets: u64,
    ticket_price: u64,
    max_tickets: u64,
    clock: &Clock,
    end_date: u64,
    status: u8,
    ctx: &TxContext,
) {
    assert!((end_date > clock::timestamp_ms(clock) && status == IN_PROGRESS), ERaffleExpired);
    assert!(amount_tickets > 0 && coin::value(&payment) > 0, EInvalidTicketCount);
    assert!(coin::value(&payment) >= amount_tickets * ticket_price, EInsufficientPayment);
    assert!(participants.length() + amount_tickets <= max_tickets, EExceedsMaxTickets);

    coin::put(balance, payment);
    let mut i = 0;
    while (i < amount_tickets) {
        participants.push_back(sender(ctx));
        i = i + 1;
    };
}

fun pick_winner(
    participants: &vector<address>,
    min_tickets: u64,
    max_tickets: u64,
    end_date: u64,
    status: u8,
    clock: &Clock,
    r: &Random,
    ctx: &mut TxContext,
): (u8, address) {
    assert!(
        (end_date <= clock.timestamp_ms()) || (participants.length() == max_tickets),
        ERaffleNotReady,
    );
    assert!(status == IN_PROGRESS, EGameAlreadyCompleted);

    if (participants.length() < min_tickets) {
        return (FAILED, @0x0)
    };

    let mut generator = r.new_generator(ctx);
    let random_index = generator.generate_u64_in_range(0, participants.length() - 1);
    let winner = *participants.borrow(random_index);
    (COMPLETED, winner)
}

#[allow(lint(self_transfer))]
fun refund_participant<Payment>(
    participants: &mut vector<address>,
    balance: &mut Balance<Payment>,
    ticket_price: u64,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    let length = participants.length();
    let mut new_participants = vector::empty();
    let mut tickets = 0;

    while (i < length) {
        if (*participants.borrow(i) == ctx.sender()) {
            tickets = tickets + 1;
        } else {
            new_participants.push_back(*participants.borrow(i));
        };
        i = i + 1;
    };

    if (tickets > 0) {
        assert!(balance.value() >= tickets * ticket_price, EInsufficientPayment);
        *participants = new_participants;
        let refund = coin::from_balance(balance.split(tickets * ticket_price), ctx);
        transfer::public_transfer(refund, ctx.sender());
    };
}

// === TEST HELPERS ===
#[test_only]
public fun get_participants<Reward, Payment>(r: &Raffle<Reward, Payment>): vector<address> {
    r.participants
}
#[test_only]
public fun get_balance<Reward, Payment>(r: &Raffle<Reward, Payment>): &Balance<Payment> {
    &r.balance
}
#[test_only]
public fun get_reward<Reward, Payment>(r: &Raffle<Reward, Payment>): &Balance<Reward> { &r.reward }
#[test_only]
public fun get_winner<Reward, Payment>(r: &Raffle<Reward, Payment>): address { r.winner }
#[test_only]
public fun get_status<Reward, Payment>(r: &Raffle<Reward, Payment>): u8 { r.status }
#[test_only]
public fun get_nft_participants<T: key + store, Payment>(
    r: &NFTRaffle<T, Payment>,
): vector<address> { r.participants }
#[test_only]
public fun get_nft_balance<T: key + store, Payment>(r: &NFTRaffle<T, Payment>): &Balance<Payment> {
    &r.balance
}
#[test_only]
public fun has_nft_reward<T: key + store, Payment>(r: &NFTRaffle<T, Payment>): bool {
    option::is_some(&r.reward)
}
#[test_only]
public fun get_nft_winner<T: key + store, Payment>(r: &NFTRaffle<T, Payment>): address { r.winner }
#[test_only]
public fun get_nft_status<T: key + store, Payment>(r: &NFTRaffle<T, Payment>): u8 { r.status }
