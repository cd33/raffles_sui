#[test_only]
module raffles::raffles_tests;

use raffles::raffles::{
    Raffle,
    EGameAlreadyCompleted,
    buy_ticket,
    create_raffle,
    create_raffle_for_testing,
    determine_winner,
    get_participants,
    get_balance,
    get_reward,
    get_winner,
    get_status,
    redeem,
    redeem_owner
};
use sui::clock;
use sui::coin;
use sui::random::{Self, Random};
use sui::test_scenario;
use sui::test_utils;

const ZERO_ADDRESS: address = @0x0;
const ADMIN: address = @0x777;
// const ADMIN_2: address = @0x888;
const PAYEE: address = @0x999;
// const BIDDER_1: address = @0xb1;
// const BIDDER_2: address = @0xb2;
// const RANDO: address = @0xbabe;

public struct TestRunner {
    scen: test_scenario::Scenario,
    raffle: Raffle,
}

const HOUR: u64 = 3600 * 1000;

public fun begin(): TestRunner {
    let mut scen = test_scenario::begin(ADMIN);
    let mut clock_end_date = clock::create_for_testing(scen.ctx());
    let payment = coin::mint_for_testing(100_000_000_000, scen.ctx());

    let min_tickets = 9;
    let max_tickets = 10;
    let ticket_price = 20_000_000_000;

    clock_end_date.set_for_testing(24*HOUR);

    let raffle = create_raffle_for_testing(
        payment,
        clock::timestamp_ms(&clock_end_date),
        min_tickets,
        max_tickets,
        ticket_price,
        scen.ctx(),
    );

    clock::destroy_for_testing(clock_end_date);

    return TestRunner {
        scen,
        raffle,
    }
}

public fun begin_to_end_raffle(): TestRunner {
    let mut runner = begin();
    let mut ctx_payee = tx_context::new_from_hint(PAYEE, 0, 0, 0, 0);
    let payment = coin::mint_for_testing(60_000_000_000, runner.scen.ctx());
    let payment_payee = coin::mint_for_testing(100_000_000_000, runner.scen.ctx());

    let clock = clock::create_for_testing(runner.scen.ctx());
    buy_ticket(&mut runner.raffle, 3, &clock, payment, runner.scen.ctx());
    buy_ticket(&mut runner.raffle, 5, &clock, payment_payee, &mut ctx_payee);

    clock::destroy_for_testing(clock);

    return runner
}
// ***********************************************************

#[test]
fun test_create_raffle() {
    let mut ctx = tx_context::dummy();
    let clock = clock::create_for_testing(&mut ctx);
    let payment = coin::mint_for_testing(100_000_000_000, &mut ctx);
    let end_date = 24*HOUR;
    let min_tickets = 5;
    let max_tickets = 10;
    let ticket_price = 10;

    create_raffle(
        &clock,
        payment,
        end_date,
        min_tickets,
        max_tickets,
        ticket_price,
        &mut ctx,
    );

    clock::destroy_for_testing(clock);
}

#[test]
fun test_buy_ticket() {
    let mut runner = begin();
    let clock = clock::create_for_testing(runner.scen.ctx());
    let payment = coin::mint_for_testing(20_000_000_000, runner.scen.ctx());
    let mut ctx_payee = tx_context::new_from_hint(PAYEE, 0, 0, 0, 0);
    let payment_payee = coin::mint_for_testing(60_000_000_000, runner.scen.ctx());

    assert!(get_participants(&runner.raffle).length() == 0);
    assert!(get_balance(&runner.raffle).value() == 0);

    buy_ticket(&mut runner.raffle, 1, &clock, payment, runner.scen.ctx());

    assert!(get_participants(&runner.raffle).length() == 1);
    assert!(get_participants(&runner.raffle).borrow(0) == @0x777);
    assert!(get_balance(&runner.raffle).value() == 20_000_000_000);

    buy_ticket(&mut runner.raffle, 3, &clock, payment_payee, &mut ctx_payee);

    assert!(get_participants(&runner.raffle).length() == 4);
    assert!(get_participants(&runner.raffle) == vector[@0x777, @0x999, @0x999, @0x999]);
    assert!(get_balance(&runner.raffle).value() == 80_000_000_000);

    clock::destroy_for_testing(clock);
    test_utils::destroy(runner);
}

#[test]
#[expected_failure(abort_code = EGameAlreadyCompleted)]
fun test_failed_redeem_without_determine_winner() {
    let mut runner = begin_to_end_raffle();

    assert!(get_balance(&runner.raffle).value() == 160000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);
    assert!(get_winner(&runner.raffle) == @0x0);
    assert!(get_status(&runner.raffle) == 0);

    redeem(&mut runner.raffle, runner.scen.ctx());

    test_utils::destroy(runner);
}

#[test]
fun test_redeem_status_failed() {
    let mut runner = begin_to_end_raffle();
    let mut clock = clock::create_for_testing(runner.scen.ctx());
    clock.set_for_testing(48*HOUR);

    let mut ts = test_scenario::begin(ZERO_ADDRESS);
    random::create_for_testing(ts.ctx());
    ts.next_tx(ZERO_ADDRESS);
    let random_state: Random = ts.take_shared();

    assert!(get_balance(&runner.raffle).value() == 160000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);
    assert!(get_winner(&runner.raffle) == @0x0);
    assert!(get_status(&runner.raffle) == 0);

    determine_winner(
        &mut runner.raffle,
        &random_state,
        &clock,
        runner.scen.ctx(),
    );

    assert!(get_winner(&runner.raffle) == @0x0);
    assert!(get_status(&runner.raffle) == 2);
    assert!(
        get_participants(&runner.raffle) == vector[ @0x777, @0x777, @0x777, @0x999, @0x999, @0x999, @0x999, @0x999],
    );

    redeem(&mut runner.raffle, runner.scen.ctx());

    assert!(get_participants(&runner.raffle) == vector[@0x999, @0x999, @0x999, @0x999, @0x999]);
    assert!(get_balance(&runner.raffle).value() == 100000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);

    clock::destroy_for_testing(clock);
    test_scenario::return_shared(random_state);
    test_utils::destroy(runner);
    ts.end();
}

#[test]
fun test_redeem_status_completed() {
    let mut runner = begin_to_end_raffle();
    let mut clock = clock::create_for_testing(runner.scen.ctx());
    let payment = coin::mint_for_testing(20_000_000_000, runner.scen.ctx());

    let mut ts = test_scenario::begin(ZERO_ADDRESS);
    random::create_for_testing(ts.ctx());
    ts.next_tx(ZERO_ADDRESS);
    let random_state: Random = ts.take_shared();
    // random_state.update_randomness_state_for_testing(
    //     0,
    //     x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
    //     ts.ctx(),
    // );

    buy_ticket(&mut runner.raffle, 1, &clock, payment, runner.scen.ctx());

    assert!(get_balance(&runner.raffle).value() == 180000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);
    assert!(
        get_participants(&runner.raffle) == vector[ @0x777, @0x777, @0x777, @0x999, @0x999, @0x999, @0x999, @0x999, @0x777],
    );
    assert!(get_winner(&runner.raffle) == @0x0);
    assert!(get_status(&runner.raffle) == 0);

    clock.set_for_testing(48*HOUR);

    determine_winner(
        &mut runner.raffle,
        &random_state,
        &clock,
        runner.scen.ctx(),
    );

    assert!(get_winner(&runner.raffle) == ADMIN);
    assert!(get_status(&runner.raffle) == 1);

    redeem(&mut runner.raffle, runner.scen.ctx());

    assert!(get_balance(&runner.raffle).value() == 180000000000);
    assert!(get_reward(&runner.raffle).value() == 0);

    clock::destroy_for_testing(clock);
    test_scenario::return_shared(random_state);
    test_utils::destroy(runner);
    ts.end();
}

#[test]
fun test_redeem_owner_status_failed() {
    let mut runner = begin_to_end_raffle();
    let mut clock = clock::create_for_testing(runner.scen.ctx());
    clock.set_for_testing(48*HOUR);

    let mut ts = test_scenario::begin(ZERO_ADDRESS);
    random::create_for_testing(ts.ctx());
    ts.next_tx(ZERO_ADDRESS);
    let random_state: Random = ts.take_shared();

    determine_winner(
        &mut runner.raffle,
        &random_state,
        &clock,
        runner.scen.ctx(),
    );

    assert!(get_balance(&runner.raffle).value() == 160000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);

    redeem_owner(&mut runner.raffle, runner.scen.ctx());

    assert!(get_balance(&runner.raffle).value() == 160000000000);
    assert!(get_reward(&runner.raffle).value() == 0);

    clock::destroy_for_testing(clock);
    test_scenario::return_shared(random_state);
    test_utils::destroy(runner);
    ts.end();
}

#[test]
fun test_redeem_owner_status_completed() {
    let mut runner = begin_to_end_raffle();
    let mut clock = clock::create_for_testing(runner.scen.ctx());
    let payment = coin::mint_for_testing(20_000_000_000, runner.scen.ctx());

    let mut ts = test_scenario::begin(ZERO_ADDRESS);
    random::create_for_testing(ts.ctx());
    ts.next_tx(ZERO_ADDRESS);
    let random_state: Random = ts.take_shared();

    buy_ticket(&mut runner.raffle, 1, &clock, payment, runner.scen.ctx());
    clock.set_for_testing(48*HOUR);

    determine_winner(
        &mut runner.raffle,
        &random_state,
        &clock,
        runner.scen.ctx(),
    );

    assert!(get_balance(&runner.raffle).value() == 180000000000);
    assert!(get_reward(&runner.raffle).value() == 100000000000);

    redeem_owner(&mut runner.raffle, runner.scen.ctx());

    assert!(get_balance(&runner.raffle).value() == 0);
    assert!(get_reward(&runner.raffle).value() == 100000000000);

    clock::destroy_for_testing(clock);
    test_scenario::return_shared(random_state);
    test_utils::destroy(runner);
    ts.end();
}

// ********************** SCENARIOS **********************
// #[test]
// fun test_scenario() {}
// ***********************************************************
