module raffles::raffles;

use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::Random;
use sui::sui::SUI;
use sui::tx_context::sender;

const EGameAlreadyCompleted: u64 = 0;
const EInvalidClock: u64 = 1;
const EInvalidTickets: u64 = 2;
const EInvalidPayment: u64 = 3;
const EInvalidOwner: u64 = 4;
const IN_PROGRESS: u8 = 0;
const COMPLETED: u8 = 1;
const FAILED: u8 = 2;

public struct RaffleCreated has copy, drop {
    id: object::ID,
}

public struct AdminCap has key, store {
    id: UID,
}

public struct Raffle has key {
    id: UID,
    reward: Balance<SUI>,
    owner: address,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    participants: vector<address>,
    balance: Balance<SUI>,
    winner: address,
    status: u8,
}

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender())
}

public fun create_raffle(
    clock: &Clock,
    payment: Coin<SUI>,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    ctx: &mut TxContext,
) {
    assert!(end_date > clock::timestamp_ms(clock), EInvalidClock);
    assert!(coin::value(&payment) > 0, EInvalidPayment);
    assert!(min_tickets < max_tickets, EInvalidTickets);
    assert!(ticket_price > 0, EInvalidTickets);
    let raffle = Raffle {
        id: object::new(ctx),
        reward: coin::into_balance(payment),
        owner: ctx.sender(),
        end_date,
        min_tickets,
        max_tickets,
        ticket_price,
        participants: vector::empty(),
        balance: balance::zero(),
        winner: @0x0,
        status: IN_PROGRESS,
    };

    event::emit(RaffleCreated {
        id: object::uid_to_inner(&raffle.id),
    });

    transfer::share_object(raffle);
}

public fun buy_ticket(
    raffle: &mut Raffle,
    amount_tickets: u64,
    clock: &Clock,
    payment: Coin<SUI>,
    ctx: &mut TxContext,
) {
    assert!(raffle.end_date > clock::timestamp_ms(clock), EInvalidClock);
    assert!(amount_tickets > 0 && coin::value(&payment) > 0, EInvalidTickets);
    assert!(coin::value(&payment) >= amount_tickets * raffle.ticket_price, EInvalidTickets);
    assert!(raffle.participants.length() + amount_tickets <= raffle.max_tickets, EInvalidTickets);

    coin::put(&mut raffle.balance, payment);
    let mut i = 0;
    while (i < amount_tickets) {
        raffle.participants.push_back(sender(ctx));
        i = i + 1;
    }
}

entry fun determine_winner(raffle: &mut Raffle, r: &Random, clock: &Clock, ctx: &mut TxContext) {
    assert!(
        (raffle.end_date <= clock.timestamp_ms()) ||
    (raffle.participants.length() == raffle.max_tickets),
        EInvalidClock,
    );
    assert!(raffle.status == IN_PROGRESS, EGameAlreadyCompleted);

    if (raffle.participants.length() < raffle.min_tickets) {
        return raffle.status = FAILED
    };

    raffle.status = COMPLETED;
    let mut generator = r.new_generator(ctx);
    let random_number = generator.generate_u64_in_range(1, raffle.participants.length());
    let winner = *raffle.participants.borrow(random_number);
    raffle.winner = winner;
}

#[allow(lint(self_transfer))]
public fun redeem(raffle: &mut Raffle, ctx: &mut TxContext) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    if (raffle.status == FAILED) {
        let mut i = 0;
        let length = raffle.participants.length();
        let mut new_participants = vector::empty();
        let mut tickets = 0;
        while (i < length) {
            if (raffle.participants.borrow(i) == ctx.sender()) {
                tickets = tickets + 1;
            } else {
                new_participants.push_back(*raffle.participants.borrow(i));
            };
            i = i + 1;
        };
        if (tickets > 0) {
            raffle.participants = new_participants;
            let refund = coin::from_balance(
                raffle.balance.split(tickets * raffle.ticket_price),
                ctx,
            );
            transfer::public_transfer(refund, ctx.sender());
        };
    } else {
        if (raffle.reward.value() > 0) {
            let refund = coin::from_balance(
                raffle.reward.withdraw_all(),
                ctx,
            );
            transfer::public_transfer(refund, raffle.winner);
        };
    }
}

public fun redeem_owner(raffle: &mut Raffle, ctx: &mut TxContext) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);
    if (raffle.status == FAILED) {
        let refund = coin::from_balance(
            raffle.reward.withdraw_all(),
            ctx,
        );
        transfer::public_transfer(refund, raffle.owner);
    } else {
        if (raffle.balance.value() > 0) {
            let refund = coin::from_balance(
                raffle.balance.withdraw_all(),
                ctx,
            );
            transfer::public_transfer(refund, raffle.owner);
        }
    }
}

#[test_only]
public fun create_raffle_for_testing(
    payment: Coin<SUI>,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
    ctx: &mut TxContext,
): Raffle {
    Raffle {
        id: object::new(ctx),
        reward: coin::into_balance(payment),
        owner: ctx.sender(),
        end_date,
        min_tickets,
        max_tickets,
        ticket_price,
        participants: vector::empty(),
        balance: balance::zero(),
        winner: @0x0,
        status: IN_PROGRESS,
    }
}
#[test_only]
public fun get_participants(raffle: &Raffle): vector<address> {
    raffle.participants
}
#[test_only]
public fun get_balance(raffle: &Raffle): &Balance<SUI> {
    &raffle.balance
}
#[test_only]
public fun get_reward(raffle: &Raffle): &Balance<SUI> {
    &raffle.reward
}
#[test_only]
public fun get_winner(raffle: &Raffle): address {
    raffle.winner
}
#[test_only]
public fun get_status(raffle: &Raffle): u8 {
    raffle.status
}
