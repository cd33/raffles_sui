module raffles::raffles;

use std::string::{Self, String};
use std::type_name;
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
const ECoinNotWhitelisted: u64 = 11;
const ENFTNotWhitelisted: u64 = 12;

// === RAFFLE STATUSES ===
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

// === WHITELIST REGISTRY ===
public struct WhitelistRegistry has key {
    id: UID,
    admin: address,
    whitelisted_coins: vector<std::string::String>,
    whitelisted_nfts: vector<std::string::String>,
}

// === STRUCTURES ===
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
    let admin_address = ctx.sender();

    // Create and transfer AdminCap
    transfer::transfer(AdminCap { id: object::new(ctx) }, admin_address);

    // Create WhitelistRegistry
    let registry = WhitelistRegistry {
        id: object::new(ctx),
        admin: admin_address,
        whitelisted_coins: vector::empty(),
        whitelisted_nfts: vector::empty(),
    };
    transfer::share_object(registry);
}

// === RAFFLE CREATION ===
public fun create_raffle<Reward, Payment>(
    registry: &WhitelistRegistry,
    clock: &Clock,
    reward: Coin<Reward>,
    ticket_price: u64,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    check_coin_whitelist<Reward>(registry);
    check_coin_whitelist<Payment>(registry);

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
    registry: &WhitelistRegistry,
    clock: &Clock,
    reward_nft: T,
    ticket_price: u64,
    end_date: u64,
    min_tickets: u64,
    max_tickets: u64,
    ctx: &mut TxContext,
) {
    check_nft_whitelist<T>(registry);
    check_coin_whitelist<Payment>(registry);

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

    if (status == COMPLETED) {
        event::emit(WinnerSelected { raffle_id: object::uid_to_inner(&raffle.id), winner });
    }
}

// === REDEEM FUNCTIONS ===
#[allow(lint(self_transfer))]
public fun redeem<Reward, Payment>(raffle: &mut Raffle<Reward, Payment>, ctx: &mut TxContext) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    let raffle_id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        refund_participant(
            raffle_id,
            &mut raffle.participants,
            &mut raffle.balance,
            raffle.ticket_price,
            ctx,
        );
    } else {
        internal_redeem_balance(raffle_id, false, &mut raffle.reward, raffle.winner, ctx);
    };
}

#[allow(lint(self_transfer))]
public fun redeem_nft<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    let raffle_id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        refund_participant(
            raffle_id,
            &mut raffle.participants,
            &mut raffle.balance,
            raffle.ticket_price,
            ctx,
        );
    } else if (option::is_some(&raffle.reward)) {
        let nft = option::extract(&mut raffle.reward);
        transfer::public_transfer(nft, raffle.winner);
        event::emit(RewardRedeemed { raffle_id, winner: raffle.winner });
    };
}

public fun redeem_owner<Reward, Payment>(
    raffle: &mut Raffle<Reward, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);
    let raffle_id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        internal_redeem_balance(
            raffle_id,
            true,
            &mut raffle.reward,
            raffle.owner,
            ctx,
        );
    } else {
        internal_redeem_balance(
            raffle_id,
            false,
            &mut raffle.balance,
            raffle.owner,
            ctx,
        );
    }
}

public fun redeem_nft_owner<T: key + store, Payment>(
    raffle: &mut NFTRaffle<T, Payment>,
    ctx: &mut TxContext,
) {
    assert!(raffle.status != IN_PROGRESS, EGameAlreadyCompleted);
    assert!(raffle.owner == ctx.sender(), EInvalidOwner);
    let raffle_id = object::uid_to_inner(&raffle.id);

    if (raffle.status == FAILED) {
        if (option::is_some(&raffle.reward)) {
            let nft = option::extract(&mut raffle.reward);
            transfer::public_transfer(nft, raffle.owner);
            event::emit(RefundIssued { raffle_id, user: raffle.owner, amount: 0 });
        };
    } else if (raffle.balance.value() > 0) {
        internal_redeem_balance(
            raffle_id,
            false,
            &mut raffle.balance,
            raffle.owner,
            ctx,
        );
    }
}

// === WHITELIST MANAGEMENT ===
public fun add_coin_to_whitelist(
    _: &AdminCap,
    registry: &mut WhitelistRegistry,
    coin_type: String,
) {
    if (!vector::contains(&registry.whitelisted_coins, &coin_type)) {
        vector::push_back(&mut registry.whitelisted_coins, coin_type);
    }
}

public fun remove_coin_from_whitelist(
    _: &AdminCap,
    registry: &mut WhitelistRegistry,
    coin_type: String,
) {
    let (found, index) = vector::index_of(&registry.whitelisted_coins, &coin_type);
    if (found) {
        vector::remove(&mut registry.whitelisted_coins, index);
    }
}

public fun add_nft_to_whitelist(_: &AdminCap, registry: &mut WhitelistRegistry, nft_type: String) {
    if (!vector::contains(&registry.whitelisted_nfts, &nft_type)) {
        vector::push_back(&mut registry.whitelisted_nfts, nft_type);
    }
}

public fun remove_nft_from_whitelist(
    _: &AdminCap,
    registry: &mut WhitelistRegistry,
    nft_type: String,
) {
    let (found, index) = vector::index_of(&registry.whitelisted_nfts, &nft_type);
    if (found) {
        vector::remove(&mut registry.whitelisted_nfts, index);
    }
}

// Fonction helper pour normaliser un type en retirant le préfixe 0x et en paddant l'adresse
fun normalize_type_string(type_str: String): String {
    let bytes = type_str.as_bytes();

    // Si le type commence par "0x", on le retire
    if (bytes.length() >= 2 && *bytes.borrow(0) == 48 && *bytes.borrow(1) == 120) {
        // Extraire la partie après "0x"
        let mut new_bytes = vector::empty<u8>();
        let mut i = 2;
        while (i < bytes.length()) {
            vector::push_back(&mut new_bytes, *bytes.borrow(i));
            i = i + 1;
        };
        string::utf8(new_bytes)
    } else {
        type_str
    }
}

fun check_coin_whitelist<T>(registry: &WhitelistRegistry) {
    let type_name_ascii = type_name::with_original_ids<T>();
    let type_name_str = string::utf8(*type_name_ascii.into_string().as_bytes());

    // Vérifier d'abord avec le type exact tel que retourné par type_name
    if (vector::contains(&registry.whitelisted_coins, &type_name_str)) {
        return
    };

    // Sinon, normaliser et chercher dans la whitelist normalisée
    let normalized_type = normalize_type_string(type_name_str);

    // Vérifier chaque entrée de la whitelist en la normalisant
    let mut i = 0;
    while (i < registry.whitelisted_coins.length()) {
        let whitelisted = *registry.whitelisted_coins.borrow(i);
        let normalized_whitelisted = normalize_type_string(whitelisted);

        if (normalized_whitelisted == normalized_type) {
            return
        };
        i = i + 1;
    };

    // Si aucune correspondance trouvée, abort
    abort ECoinNotWhitelisted
}

fun check_nft_whitelist<T>(registry: &WhitelistRegistry) {
    let type_name_ascii = type_name::with_original_ids<T>();
    let type_name_str = string::utf8(*type_name_ascii.into_string().as_bytes());

    // Vérifier d'abord avec le type exact
    if (vector::contains(&registry.whitelisted_nfts, &type_name_str)) {
        return
    };

    // Sinon, normaliser et chercher
    let normalized_type = normalize_type_string(type_name_str);

    let mut i = 0;
    while (i < registry.whitelisted_nfts.length()) {
        let whitelisted = *registry.whitelisted_nfts.borrow(i);
        let normalized_whitelisted = normalize_type_string(whitelisted);

        if (normalized_whitelisted == normalized_type) {
            return
        };
        i = i + 1;
    };

    abort ENFTNotWhitelisted
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
    raffle_id: object::ID,
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
        participants.push_back(ctx.sender());
        i = i + 1;
    };

    event::emit(TicketPurchased {
        raffle_id,
        buyer: ctx.sender(),
        tickets: amount_tickets,
        total_paid: amount_tickets * ticket_price,
    });
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

fun internal_redeem_balance<T>(
    raffle_id: object::ID,
    is_refund: bool,
    balance: &mut Balance<T>,
    recipient: address,
    ctx: &mut TxContext,
) {
    if (balance.value() > 0) {
        let reward = coin::from_balance(balance.withdraw_all(), ctx);
        let amount = coin::value(&reward);
        transfer::public_transfer(reward, recipient);
        if (is_refund) {
            event::emit(RefundIssued { raffle_id, user: recipient, amount });
        } else {
            event::emit(RewardRedeemed { raffle_id, winner: recipient });
        }
    };
}

#[allow(lint(self_transfer))]
fun refund_participant<Payment>(
    raffle_id: object::ID,
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
        let refund_amount = tickets * ticket_price;
        assert!(balance.value() >= refund_amount, EInsufficientPayment);
        *participants = new_participants;
        let refund = coin::from_balance(balance.split(refund_amount), ctx);
        transfer::public_transfer(refund, ctx.sender());
        event::emit(RefundIssued { raffle_id, user: ctx.sender(), amount: refund_amount });
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
#[test_only]
public fun create_test_registry_with_types<T, Payment>(
    is_nft: bool,
    ctx: &mut TxContext,
): WhitelistRegistry {
    if (is_nft) {
        let reward_type_name = type_name::with_original_ids<T>();
        let reward_type_str = string::utf8(*reward_type_name.into_string().as_bytes());

        let payment_type_name = type_name::with_original_ids<Payment>();
        let payment_type_str = string::utf8(*payment_type_name.into_string().as_bytes());

        let mut whitelisted_coins = vector::empty();
        vector::push_back(&mut whitelisted_coins, payment_type_str);

        let mut whitelisted_nfts = vector::empty();
        vector::push_back(&mut whitelisted_nfts, reward_type_str);

        WhitelistRegistry {
            id: object::new(ctx),
            admin: ctx.sender(),
            whitelisted_coins,
            whitelisted_nfts,
        }
    } else {
        let reward_type_name = type_name::with_original_ids<T>();
        let reward_type_str = string::utf8(*reward_type_name.into_string().as_bytes());

        let payment_type_name = type_name::with_original_ids<Payment>();
        let payment_type_str = string::utf8(*payment_type_name.into_string().as_bytes());

        let mut whitelisted_coins = vector::empty();
        vector::push_back(&mut whitelisted_coins, reward_type_str);
        vector::push_back(&mut whitelisted_coins, payment_type_str);

        WhitelistRegistry {
            id: object::new(ctx),
            admin: ctx.sender(),
            whitelisted_coins,
            whitelisted_nfts: vector::empty(),
        }
    }
}
#[test_only]
public fun create_and_share_test_registry<T, Payment>(
    is_nft: bool,
    ctx: &mut TxContext,
): object::ID {
    let registry = create_test_registry_with_types<T, Payment>(is_nft, ctx);
    let id = object::uid_to_inner(&registry.id);
    transfer::share_object(registry);
    id
}
#[test_only]
public fun create_and_share_empty_registry(ctx: &mut TxContext): object::ID {
    let registry = WhitelistRegistry {
        id: object::new(ctx),
        admin: ctx.sender(),
        whitelisted_coins: vector::empty(),
        whitelisted_nfts: vector::empty(),
    };
    let id = object::uid_to_inner(&registry.id);
    transfer::share_object(registry);
    id
}
#[test_only]
public fun create_test_admin_cap(ctx: &mut TxContext): AdminCap {
    AdminCap { id: object::new(ctx) }
}
#[test_only]
public fun get_whitelisted_coins(registry: &WhitelistRegistry): &vector<String> {
    &registry.whitelisted_coins
}
#[test_only]
public fun get_whitelisted_nfts(registry: &WhitelistRegistry): &vector<String> {
    &registry.whitelisted_nfts
}
#[test_only]
public fun is_coin_whitelisted(registry: &WhitelistRegistry, coin_type: String): bool {
    vector::contains(&registry.whitelisted_coins, &coin_type)
}
#[test_only]
public fun is_nft_whitelisted(registry: &WhitelistRegistry, nft_type: String): bool {
    vector::contains(&registry.whitelisted_nfts, &nft_type)
}
