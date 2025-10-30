module raffles::raffles_participants;

use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::Random;
use sui::tx_context::sender;

// === ERROR CODES ===
const EGameAlreadyCompleted: u64 = 0;
const EInvalidEndDate: u64 = 1;
const EInvalidRewardAmount: u64 = 2;
const EInvalidTicketConfiguration: u64 = 3;
const EInvalidTicketPrice: u64 = 4;
const EInvalidOwner: u64 = 5;
const ERaffleExpired: u64 = 6;
const EInvalidTicketCount: u64 = 7;
const EInsufficientPayment: u64 = 8;
const EExceedsMaxTickets: u64 = 9;
const ERaffleNotReady: u64 = 10;

// === STATUSES ===
const IN_PROGRESS: u8 = 0;
const COMPLETED: u8 = 1;
const FAILED: u8 = 2;

// === EVENTS ===
public struct RaffleCreated has copy, drop { id: object::ID }
public struct NFTRaffleCreated has copy, drop { id: object::ID }
public struct TicketPurchased has copy, drop {
    raffle_id: object::ID,
    buyer: address,
    tickets: u64,
    total_paid: u64,
}
public struct WinnerSelected has copy, drop { raffle_id: object::ID, winner: address }
public struct RefundIssued has copy, drop { raffle_id: object::ID, user: address, amount: u64 }
public struct RewardRedeemed has copy, drop { raffle_id: object::ID, winner: address }

// === ADMIN CAP ===
public struct AdminCap has key, store { id: UID }

// === STRUCTURES ===
public struct Participant has copy, drop, store {
    user: address,
    tickets: u64,
}

public struct Raffle<phantom Reward, phantom Payment> has key {
    id: UID,
    reward: Balance<Reward>,
    owner: address,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    participants: vector<Participant>,
    balance: Balance<Payment>,
    winner: address,
    status: u8,
}

public struct NFTRaffle<T: key + store, phantom Payment> has key {
    id: UID,
    reward: option::Option<T>,
    owner: address,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    participants: vector<Participant>,
    balance: Balance<Payment>,
    winner: address,
    status: u8,
}

// === INIT ===
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
        object::uid_to_inner(&raffle.id),
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
        object::uid_to_inner(&raffle.id),
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

// === WINNER SELECTION (pondérée) ===
entry fun determine_winner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    r: &Random,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (status, winner) = pick_weighted_winner(
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

    if (status == COMPLETED) {
        event::emit(WinnerSelected { raffle_id: object::uid_to_inner(&raffle.id), winner });
    }
}

entry fun determine_nft_winner<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    r: &Random,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let (status, winner) = pick_weighted_winner(
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

    if (status == COMPLETED) {
        event::emit(WinnerSelected { raffle_id: object::uid_to_inner(&raffle.id), winner });
    }
}

// === FACTORIZED REDEEM LOGIC ===
fun internal_redeem_balance<Reward>(
    raffle_id: object::ID,
    balance: &mut Balance<Reward>,
    recipient: address,
    ctx: &mut TxContext,
) {
    if (balance.value() > 0) {
        let reward = coin::from_balance(balance.withdraw_all(), ctx);
        transfer::public_transfer(reward, recipient);
        event::emit(RewardRedeemed { raffle_id, winner: recipient });
    };
}

#[allow(lint(self_transfer))]
public fun redeem<Reward, Payment>(raffle: &mut Raffle<Reward, Payment>, ctx: &mut TxContext) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    let id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        refund_participant(
            id,
            &mut raffle.participants,
            &mut raffle.balance,
            raffle.ticket_price,
            ctx,
        );
    } else {
        assert!(ctx.sender() == raffle.winner, EInvalidOwner);
        internal_redeem_balance(id, &mut raffle.reward, raffle.winner, ctx);
    }
}

#[allow(lint(self_transfer))]
public fun redeem_nft<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    let id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        refund_participant(
            id,
            &mut raffle.participants,
            &mut raffle.balance,
            raffle.ticket_price,
            ctx,
        );
    } else {
        assert!(ctx.sender() == raffle.winner, EInvalidOwner);
        if (option::is_some(&raffle.reward)) {
            let nft = option::extract(&mut raffle.reward);
            transfer::public_transfer(nft, raffle.winner);
            event::emit(RewardRedeemed { raffle_id: id, winner: raffle.winner });
        };
    }
}

// === OWNER REDEEM FACTORIZED ===
fun internal_owner_redeem<Reward, Payment>(
    raffle_id: object::ID,
    reward_balance: &mut Balance<Reward>,
    payment_balance: &mut Balance<Payment>,
    owner: address,
    status: u8,
    ctx: &mut TxContext,
) {
    if (status == FAILED) {
        internal_redeem_balance<Reward>(raffle_id, reward_balance, owner, ctx);
    } else if (payment_balance.value() > 0) {
        let payment = coin::from_balance(payment_balance.withdraw_all(), ctx);
        let amount = coin::value(&payment);
        transfer::public_transfer(payment, owner);
        event::emit(RefundIssued { raffle_id, user: owner, amount });
    }
}

public fun redeem_owner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);
    internal_owner_redeem(
        object::uid_to_inner(&raffle.id),
        &mut raffle.reward,
        &mut raffle.balance,
        raffle.owner,
        raffle.status,
        ctx,
    );
}

public fun redeem_nft_owner<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);

    let id = object::uid_to_inner(&raffle.id);
    if (raffle.status == FAILED && option::is_some(&raffle.reward)) {
        let nft = option::extract(&mut raffle.reward);
        transfer::public_transfer(nft, raffle.owner);
        event::emit(RefundIssued { raffle_id: id, user: raffle.owner, amount: 0 });
    } else if (raffle.balance.value() > 0) {
        let payment = coin::from_balance(raffle.balance.withdraw_all(), ctx);
        let amount = coin::value(&payment);
        transfer::public_transfer(payment, raffle.owner);
        event::emit(RefundIssued {
            raffle_id: id,
            user: raffle.owner,
            amount,
        });
    }
}

// === UTILITIES ===
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
    raffle_id: object::ID,
    participants: &mut vector<Participant>,
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

    let mut total_tickets = 0;
    let mut i = 0;
    while (i < vector::length(participants)) {
        let p = vector::borrow(participants, i);
        total_tickets = total_tickets + p.tickets;
        i = i + 1;
    };
    assert!(total_tickets + amount_tickets <= max_tickets, EExceedsMaxTickets);

    coin::put(balance, payment);
    append_or_update(participants, sender(ctx), amount_tickets);

    event::emit(TicketPurchased {
        raffle_id,
        buyer: sender(ctx),
        tickets: amount_tickets,
        total_paid: amount_tickets * ticket_price,
    });
}

fun append_or_update(participants: &mut vector<Participant>, user: address, tickets: u64) {
    let mut i = 0;
    let len = vector::length(participants);
    while (i < len) {
        let p = vector::borrow_mut(participants, i);
        if (p.user == user) {
            p.tickets = p.tickets + tickets;
            return
        };
        i = i + 1;
    };
    vector::push_back(participants, Participant { user, tickets });
}

fun pick_weighted_winner(
    participants: &vector<Participant>,
    min_tickets: u64,
    max_tickets: u64,
    end_date: u64,
    status: u8,
    clock: &Clock,
    r: &Random,
    ctx: &mut TxContext,
): (u8, address) {
    assert!(
        (end_date <= clock.timestamp_ms()) || (total_tickets(participants) == max_tickets),
        ERaffleNotReady,
    );
    assert!(status == IN_PROGRESS, EGameAlreadyCompleted);

    let total = total_tickets(participants);
    if (total < min_tickets) {
        return (FAILED, @0x0)
    };

    let mut generator = r.new_generator(ctx);
    let random_ticket = generator.generate_u64_in_range(0, total - 1);

    let mut cumulative = 0;
    let mut i = 0;
    while (i < vector::length(participants)) {
        let p = vector::borrow(participants, i);
        cumulative = cumulative + p.tickets;
        if (random_ticket < cumulative) {
            return (COMPLETED, p.user)
        };
        i = i + 1;
    };
    (FAILED, @0x0)
}

fun total_tickets(participants: &vector<Participant>): u64 {
    let mut total = 0;
    let mut i = 0;
    while (i < vector::length(participants)) {
        total = total + vector::borrow(participants, i).tickets;
        i = i + 1;
    };
    total
}

#[allow(lint(self_transfer))]
fun refund_participant<Payment>(
    raffle_id: object::ID,
    participants: &mut vector<Participant>,
    balance: &mut Balance<Payment>,
    ticket_price: u64,
    ctx: &mut TxContext,
) {
    let mut i = 0;
    let mut new_participants = vector::empty();
    let mut refund_amount = 0;

    while (i < vector::length(participants)) {
        let p = vector::borrow(participants, i);
        if (p.user == sender(ctx)) {
            refund_amount = refund_amount + p.tickets * ticket_price;
        } else {
            vector::push_back(&mut new_participants, *p);
        };
        i = i + 1;
    };

    if (refund_amount > 0) {
        assert!(balance.value() >= refund_amount, EInsufficientPayment);
        *participants = new_participants;
        let refund = coin::from_balance(balance.split(refund_amount), ctx);
        transfer::public_transfer(refund, sender(ctx));
        event::emit(RefundIssued { raffle_id, user: sender(ctx), amount: refund_amount });
    };
}
