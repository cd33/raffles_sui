module raffles::raffles;

use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::random::Random;
use sui::sui::SUI;
use sui::tx_context::sender;

const EInvalidClock: u64 = 0;
const EInvalidTickets: u64 = 1;
const EInvalidPayment: u64 = 2;
const EGameAlreadyCompleted: u64 = 3;
const EInvalidOwner: u64 = 4;
const IN_PROGRESS: u8 = 0;
const COMPLETED: u8 = 1;
const FAILED: u8 = 2;

public struct AdminCap has key, store {
    id: UID,
}

public struct Raffle has key, store {
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
    ctx: &mut TxContext,
    clock: &Clock,
    payment: Coin<SUI>,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
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

    transfer::share_object(raffle);
}

public fun buy_ticket(
    ctx: &mut TxContext,
    raffle: &mut Raffle,
    amount_tickets: u64,
    clock: &Clock,
    payment: Coin<SUI>,
) {
    assert!(raffle.end_date > clock::timestamp_ms(clock), EInvalidClock);
    assert!(raffle.participants.length() + amount_tickets < raffle.max_tickets, EInvalidTickets);
    assert!(coin::value(&payment) >= amount_tickets * raffle.ticket_price, EInvalidTickets);

    coin::put(&mut raffle.balance, payment);
    let mut i = 0;
    while (i < amount_tickets) {
        raffle.participants.push_back(sender(ctx));
        i = i + 1;
    }
}

entry fun determine_winner(raffle: &mut Raffle, r: &Random, clock: &Clock, ctx: &mut TxContext) {
    assert!(raffle.end_date <= clock.timestamp_ms(), EInvalidClock);
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
    ctx: &mut TxContext,
    payment: Coin<SUI>,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ticket_price: u64,
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

// public fun end_raffle(ctx: &mut TxContext, raffle: &mut Raffle, clock: &Clock) {
//     assert!(raffle.end_date <= clock::timestamp_ms(clock), EInvalidClock);

//     if (raffle.participants.length() < raffle.min_tickets) {
//         // Rembourser les acheteurs
//         let mut i = 0;
//         let length = vector::length(&raffle.participants);
//         while (i < length) {
//             let participant = raffle.participants.pop_back();
//             let participant_coin = coin::from_balance(
//                 raffle.balance.split(raffle.ticket_price),
//                 ctx,
//             );
//             transfer::public_transfer(participant_coin, participant);
//             i = i + 1;
//         };
//         raffle.participants = vector::empty();
//         let owner_coin = coin::from_balance(
//             raffle.reward.withdraw_all(),
//             ctx,
//         );
//         debug::print(&i);
//         return transfer::public_transfer(owner_coin, raffle.owner)
//     };
//     debug::print(&@0x0);
//     raffle.winner = raffle.participants.pop_back();
//     raffle.participants = vector::empty();

//     // let r = random::create(ctx);
//     // let winner = random_winner(ctx, raffle, r);
//     // debug::print(&winner);

//     // raffle.winner = raffle.participants.get(random::u64(raffle.participants.length()));

//     // si assez de tickets vendus
//     // tirage au sort
//     // transferer reward au gagnant
//     // transferer balance au vendeur
//     // let winner = raffle.tickets.get(random::u64(raffle.total_tickets));
//     // let reward = Coin { value: raffle.reward_amount, currency: SUI };

//     // coin::transfer(&mut raffle.balance, reward, winner);
//     // coin::transfer(&mut raffle.balance, coin::value(&raffle.balance), raffle.owner);
// }
