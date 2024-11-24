
module slotty::slotty_cubes_tests;
use sui::test_scenario;
use slotty::slotty_cubes;
use std::string;

#[test]
fun slotty_cubes_tests() {
    let addr = @0xA;
    let scenario = test_scenario::begin(addr);
    {
        // Create new game
        let slottyCubes = slotty_cubes::create_game(
            string::utf8(b"Slotty Cubes"), 
            vector<vector<u8>>[
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
            ], 
            vector<u64>[100000000], // 0.1 SUI or 100M Mist 
            10);
        // Get a result for rand equal to 3
        let result = slotty_cubes::get_result(&slottyCubes, 3);
        let (multiplier, symbols) = slotty_cubes::get_result_details(result);
        // Assert correct outcome
        // Can calculate this using all the game_utils functions, or just use the debug prints to find it for this specific rand
        assert!(multiplier == 3);
        assert!(symbols == vector<u8>[1, 2, 0, 2, 2]);
        slotty_cubes::destroy_game(slottyCubes);
    };
    scenario.end();
}

#[test]
fun win_multiplier_computation() {
    let addr = @0xA;
    let scenario = test_scenario::begin(addr);
    {
        // Create new game
        let slottyCubes = slotty_cubes::create_game(
            string::utf8(b"Slotty Cubes"), 
            vector<vector<u8>>[
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
                vector<u8>[0, 1, 2],
            ], 
            vector<u64>[100000000], // 0.1 SUI or 100M Mist 
            10);
        
        assert!(slotty_cubes::compute_win_multiplier(&slottyCubes, vector[1, 1, 1, 1, 1]) == 6);
        assert!(slotty_cubes::compute_win_multiplier(&slottyCubes, vector[4, 4, 4, 4, 4]) == 10); // Because it exceeds the max

        slotty_cubes::destroy_game(slottyCubes);
    };
    scenario.end();
}