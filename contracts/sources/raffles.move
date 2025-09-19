module raffles::raffles;

use sui::balance::{Self, Balance};
use sui::clock::{Self, Clock};
use sui::coin::{Self, Coin};
use sui::event;
use sui::random::Random;
use sui::tx_context::sender;

// === ERROR CODES ===
// Game/Raffle Status Errors
const EGameAlreadyCompleted: u64 = 0; // Tentative d'action sur une raffle terminée
const ERaffleNotReady: u64 = 10; // Raffle non prête pour déterminer le gagnant
// Creation/Configuration Errors
const EInvalidEndDate: u64 = 1; // Date de fin dans le passé
const EInvalidRewardAmount: u64 = 2; // Montant de récompense invalide (0)
const EInvalidTicketConfiguration: u64 = 3; // min_tickets >= max_tickets
const EInvalidTicketPrice: u64 = 4; // Prix du ticket invalide (0)
// Purchase/Payment Errors
const ERaffleExpired: u64 = 6; // Tentative d'achat après expiration
const EInvalidTicketCount: u64 = 7; // Nombre de tickets invalide (0) ou paiement vide
const EInsufficientPayment: u64 = 8; // Paiement insuffisant pour les tickets
const EExceedsMaxTickets: u64 = 9; // Dépasse le nombre maximum de tickets
// Authorization Errors
const EInvalidOwner: u64 = 5; // Seul le propriétaire peut effectuer cette action

const IN_PROGRESS: u8 = 0;
const COMPLETED: u8 = 1;
const FAILED: u8 = 2;

public struct RaffleCreated has copy, drop {
    id: object::ID,
}

public struct AdminCap has key, store {
    id: UID,
}

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

fun init(ctx: &mut TxContext) {
    transfer::transfer(AdminCap { id: object::new(ctx) }, ctx.sender())
}

public fun create_raffle<Reward, Payment>(
    clock: &Clock,
    reward: Coin<Reward>,
    ticket_price: u64,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    assert!(end_date > clock::timestamp_ms(clock), EInvalidEndDate);
    assert!(coin::value(&reward) > 0, EInvalidRewardAmount);
    assert!(min_tickets < max_tickets, EInvalidTicketConfiguration);
    assert!(ticket_price > 0, EInvalidTicketPrice);

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

    event::emit(RaffleCreated {
        id: object::uid_to_inner(&raffle.id),
    });

    transfer::share_object(raffle);
}

public fun buy_ticket<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    amount_tickets: u64,
    payment: Coin<Payment>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!((raffle.end_date > clock::timestamp_ms(clock) && raffle.status == IN_PROGRESS), ERaffleExpired);
    assert!(amount_tickets > 0 && coin::value(&payment) > 0, EInvalidTicketCount);
    assert!(coin::value(&payment) >= amount_tickets * raffle.ticket_price, EInsufficientPayment);
    assert!(
        raffle.participants.length() + amount_tickets <= raffle.max_tickets,
        EExceedsMaxTickets,
    );

    coin::put(&mut raffle.balance, payment);

    let mut i = 0;
    while (i < amount_tickets) {
        raffle.participants.push_back(sender(ctx));
        i = i + 1;
    }
}

entry fun determine_winner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    r: &Random,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    assert!(
        (raffle.end_date <= clock.timestamp_ms()) ||
        (raffle.participants.length() == raffle.max_tickets),
        ERaffleNotReady,
    );
    assert!(raffle.status == IN_PROGRESS, EGameAlreadyCompleted);

    if (raffle.participants.length() < raffle.min_tickets) {
        return raffle.status = FAILED
    };

    raffle.status = COMPLETED;
    let mut generator = r.new_generator(ctx);
    let random_number = generator.generate_u64_in_range(0, raffle.participants.length() - 1);
    let winner = *raffle.participants.borrow(random_number);
    raffle.winner = winner;
}

#[allow(lint(self_transfer))]
public fun redeem<Reward, Payment>(raffle: &mut Raffle<Reward, Payment>, ctx: &mut TxContext) {
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

public fun redeem_owner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    ctx: &mut TxContext,
) {
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
public fun get_participants<Reward, Payment>(raffle: &Raffle<Reward, Payment>): vector<address> {
    raffle.participants
}
#[test_only]
public fun get_balance<Reward, Payment>(raffle: &Raffle<Reward, Payment>): &Balance<Payment> {
    &raffle.balance
}
#[test_only]
public fun get_reward<Reward, Payment>(raffle: &Raffle<Reward, Payment>): &Balance<Reward> {
    &raffle.reward
}
#[test_only]
public fun get_winner<Reward, Payment>(raffle: &Raffle<Reward, Payment>): address {
    raffle.winner
}
#[test_only]
public fun get_status<Reward, Payment>(raffle: &Raffle<Reward, Payment>): u8 {
    raffle.status
}
