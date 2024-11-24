module slotty::game_providers_tests;

use sui::test_scenario;
use std::string;
use sui::vec_map;
use slotty::game_provider;
use slotty::slotty_cubes;
use slotty::registration;
use sui::coin;
use sui::sui::SUI;
use sui::random;

#[test]
fun play_game_success(){
    let addr = @0xA;

    // Create the random
    let mut scenario = test_scenario::begin(@0x0);
    {
        random::create_for_testing(scenario.ctx());
    };

    // WE fix the random for testing purposes
    scenario.next_tx(@0x0);
    let mut rand = scenario.take_shared<random::Random>();
    rand.update_randomness_state_for_testing(
        0,
        // x"1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
        x"0F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F1F",
        scenario.ctx(),
    );
    scenario.end();

    // Init provider module
    let mut scenario = test_scenario::begin(addr);
    {
        game_provider::test_init(scenario.ctx());
    };

    // Verify initialization
    scenario.next_tx(addr);
    {
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();

        assert!(game_provider::get_all_game_providers(&registry).keys().length() == 0);

        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
    };

    // Register the player
    scenario.next_tx(addr);
    {
        registration::register(scenario.ctx());
    };

    // Add Slotty game provider
    scenario.next_tx(addr);
    {
        let gameProviderCap = scenario.take_from_sender<game_provider::GameProviderCap>();
        let mut registry = scenario.take_shared<game_provider::GameProviderRegistry>();

        game_provider::create_new_game_provider(&gameProviderCap, &mut registry, string::utf8(b"Slotty"), scenario.ctx());
        assert!(game_provider::get_all_game_providers(&registry).keys().length() == 1);
        assert!(game_provider::get_all_game_providers(&registry).keys().contains(&string::utf8(b"Slotty")) == true);
        
        scenario.return_to_sender(gameProviderCap);
        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
    };

    // Add Slotty Cubes game
    scenario.next_tx(addr);
    {
        let gameProviderCap = scenario.take_from_sender<game_provider::GameProviderCap>();
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();

        let gameProviders = game_provider::get_all_game_providers(&registry);
        let gameProviderId = vec_map::get(&gameProviders, &string::utf8(b"Slotty"));
        let mut slottyGameProvider = scenario.take_shared_by_id<game_provider::GameProvider>(*gameProviderId);

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

        assert!(game_provider::has_game(&slottyGameProvider, string::utf8(b"Slotty Cubes")) == false);
        game_provider::add_slotty_cubes(&gameProviderCap, &mut slottyGameProvider, slottyCubes);
        assert!(game_provider::has_game(&slottyGameProvider, string::utf8(b"Slotty Cubes")) == true);
        
        scenario.return_to_sender(gameProviderCap);
        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
        test_scenario::return_shared<game_provider::GameProvider>(slottyGameProvider);
    };

    // Fund the treasury
    scenario.next_tx(addr);
    {
        let gameProviderCap = scenario.take_from_sender<game_provider::GameProviderCap>();
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();
        let gameProviders = game_provider::get_all_game_providers(&registry);
        let gameProviderId = vec_map::get(&gameProviders, &string::utf8(b"Slotty"));
        let mut slottyGameProvider = scenario.take_shared_by_id<game_provider::GameProvider>(*gameProviderId);

        let coin = coin::mint_for_testing<SUI>(10000000000, scenario.ctx()); // 10 SUI
        assert!(game_provider::get_current_balance(&gameProviderCap, &slottyGameProvider) == 0);
        game_provider::deposit(&gameProviderCap, &mut slottyGameProvider, coin);
        assert!(game_provider::get_current_balance(&gameProviderCap, &slottyGameProvider) == 10000000000);

        std::debug::print(&scenario.sender());
        scenario.return_to_sender(gameProviderCap);
        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
        test_scenario::return_shared<game_provider::GameProvider>(slottyGameProvider);
    };

    // Start a game round
    scenario.next_tx(addr);
    {
        let registration = scenario.take_from_sender<registration::PlayerRegistration>();
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();
        let gameProviders = game_provider::get_all_game_providers(&registry);
        let gameProviderId = vec_map::get(&gameProviders, &string::utf8(b"Slotty"));
        let mut slottyGameProvider = scenario.take_shared_by_id<game_provider::GameProvider>(*gameProviderId);

        let coin = coin::mint_for_testing<SUI>(100000000, scenario.ctx());

        let game_round = game_provider::start_game_round(
            &registration, 
        &mut slottyGameProvider, 
        string::utf8(b"Slotty Cubes"), 
        coin, 
        &rand, 
        scenario.ctx());

        assert!(game_provider::get_stake_amount(&game_round) == 100000000);
        std::debug::print(&game_provider::get_rand(&game_round));
        // // assert!(game_provider::get_rand(&game_round) == 5144973309768963716);
        assert!(game_provider::get_rand(&game_round) == 829328100006071506);

        transfer::public_transfer(game_round, addr);
        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
        test_scenario::return_shared<game_provider::GameProvider>(slottyGameProvider);
        scenario.return_to_sender(registration);
    };

    // Verify the treasury
    scenario.next_tx(addr);
    {
        let gameProviderCap = scenario.take_from_sender<game_provider::GameProviderCap>();
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();
        let gameProviders = game_provider::get_all_game_providers(&registry);
        let gameProviderId = vec_map::get(&gameProviders, &string::utf8(b"Slotty"));
        let slottyGameProvider = scenario.take_shared_by_id<game_provider::GameProvider>(*gameProviderId);

        assert!(game_provider::get_current_balance(&gameProviderCap, &slottyGameProvider) == 100000000 + 10000000000);

        scenario.return_to_sender(gameProviderCap);
        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
        test_scenario::return_shared<game_provider::GameProvider>(slottyGameProvider);
    };


    // Finish the game round
    scenario.next_tx(addr);
    {
        let gameProviderCap = scenario.take_from_sender<game_provider::GameProviderCap>();
        let registration = scenario.take_from_sender<registration::PlayerRegistration>();
        let registry = scenario.take_shared<game_provider::GameProviderRegistry>();
        let gameProviders = game_provider::get_all_game_providers(&registry);
        let gameProviderId = vec_map::get(&gameProviders, &string::utf8(b"Slotty"));
        let mut slottyGameProvider = scenario.take_shared_by_id<game_provider::GameProvider>(*gameProviderId);

        let game_round = scenario.take_from_sender<game_provider::GameRound>();

        let game_result = game_provider::settle_game_round(
            &registration, 
            game_round, 
        &mut slottyGameProvider, 
        scenario.ctx()
        );
        let (symbols,
            win_multiplier,
            win_amount,
            stake_amount
        ) = game_provider::get_game_result_details(&game_result);

        assert!(symbols == vector<u8>[2, 0, 1, 2 , 2]);
        assert!(win_multiplier == 3);
        assert!(win_amount == 3 * 100000000);
        assert!(stake_amount == 100000000);

        assert!(game_provider::get_current_balance(&gameProviderCap, &slottyGameProvider)
        == 100000000 + 10000000000 - 3 * 100000000);
        
        // std::debug::print(&string::utf8(b"Symbols:"));
        // std::vector::do!<u8>(symbols, |symbol| std::debug::print(&symbol) );
        //         std::debug::print(&string::utf8(b"-----"));
        // std::debug::print(&win_multiplier);
        // std::debug::print(&win_multiplier);
        // std::debug::print(&win_amount);
        // std::debug::print(&stake_amount);

        transfer::public_transfer(game_result, scenario.sender());

        test_scenario::return_shared<game_provider::GameProviderRegistry>(registry);
        test_scenario::return_shared<game_provider::GameProvider>(slottyGameProvider);
        scenario.return_to_sender(registration);
        scenario.return_to_sender(gameProviderCap);
    };


    // Verify winnings
    scenario.next_tx(addr);
    {
        let winnings_coin = scenario.take_from_sender<coin::Coin<SUI>>();
        assert!(winnings_coin.value() == 3 * 100000000);
        coin::burn_for_testing(winnings_coin);
    };
    
    test_scenario::return_shared(rand);
    scenario.end();
}