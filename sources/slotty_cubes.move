
module slotty::slotty_cubes;

use std::string;
use slotty::treasury;
use slotty::game_utils;

const EInvalidReels: u64 = 1;

public struct SlottyCubes has store {
    name: string::String,
    reels: vector<vector<u8>>,
    accepted_stakes: vector<u64>,
    max_payout_factor: u64
}

public struct GameResult {
    win_multiplier: u64,
    stake: treasury::Stake,
    symbols: vector<u8>
}

public fun create_game(name: string::String, reels: vector<vector<u8>>, accepted_stakes: vector<u64>, max_payout_factor: u64): SlottyCubes {
    let nb_of_reels = vector::length(&reels);
    assert!(nb_of_reels == 5, EInvalidReels); // Game should have 5 reels

    let mut y: u64 = 0;
    while (y < nb_of_reels) {
        let this_reel = reels[y];
        assert!(vector::length(&this_reel) > 0, EInvalidReels); // Every real should have at least 1 element
        this_reel.do!(|val| assert!(val >=0 && val < 5, EInvalidReels),); // Accepted symbols are 0, 1, 2, 3, 4
        y = y + 1;
    };

    SlottyCubes {
        name,
        reels,
        accepted_stakes,
        max_payout_factor
    }
}

public fun get_result(slotty_cubes: &SlottyCubes, stake: treasury::Stake, rand: u64): GameResult {
    // Determine output vals
    let mut output_symbols = vector::empty<u8>();
    std::u64::do!(slotty_cubes.reels.length(),  // for each reel index
    |i| {
        let reel = slotty_cubes.reels.borrow(i);
        let stopping_value = game_utils::compute_stopping_value(reel, rand, i);
        vector::push_back(&mut output_symbols, stopping_value);
    });
    // Compute the win multiplier
    let win_multiplier = compute_win_multiplier(*&output_symbols);
    GameResult { win_multiplier, stake, symbols: output_symbols }
}

public fun compute_win_multiplier(symbols: vector<u8>): u64 {
    let mut counts = vector[0u8, 0u8, 0u8, 0u8, 0u8]; // We have 5 possible symbols

    symbols.do!(|val| {
        let count_ref = vector::borrow_mut(&mut counts, val as u64); 
        *count_ref = *count_ref + 1u8;
    });
    let index = vector::find_index!(&counts, |x| *x >= 3);
    if (index.is_none()) {
        0 as u64
    }
    else {
        let mut base_mul:u64 = 1;
        let symbol = index.borrow();
        // Symbol value multiplier
        if (symbol == 0){
            base_mul = base_mul * 1;
        }
        else if (symbol == 1){
            base_mul = base_mul * 2;
        }
        else if (symbol == 2){
            base_mul = base_mul * 3;
        }
        else if (symbol == 3){
            base_mul = base_mul * 4;
        }
        else if (symbol == 4){
            base_mul = base_mul * 5;
        };

        // Count multiplier
        let count = counts[*symbol];
        if (count == 3){
            base_mul = base_mul * 1;
        }
        else if (count == 4){
            base_mul = base_mul * 2;
        }
        else if (count == 5){
            base_mul = base_mul * 3;
        };
        base_mul
    }

}

public fun get_name(game: &SlottyCubes): string::String {
    game.name
}

public fun get_max_payout_factor(game: &SlottyCubes): u64 {
    game.max_payout_factor
}