module slotty::game_provider;

use std::string;
use slotty::treasury;
use slotty::slotty_cubes;
use slotty::registration;
use sui::bag;
use sui::types;
use sui::coin;
use sui::sui::SUI;
use sui::random;
use sui::vec_map;


const EIncompatibleGameProvider: u64 = 1;
const EGameProviderAlreadyExists: u64 = 2;
const EInsufficientFundsInTreasury: u64 = 3;
// const ENoActiveGameRound: u64 = 4;
const EGameDoesNotExist: u64 = 5;

// Represents admin capabilities over the game providers (Capability pattern)
public struct GameProviderCap has key, store {
    id: UID
}

// Game provider, responsible for managing a set of games
// note that each game provider has its own treasury
public struct GameProvider has key {
    id: UID,
    name: string::String,
    treasury: treasury::Treasury,
    games: bag::Bag
}

public struct GameProviderRegistry has key {
    id: UID,
    providerMap: vec_map::VecMap<string::String, ID>
}

public struct GameRound has key, store {
    id: UID,
    player_registration_id: ID,
    stake: treasury::Stake,
    game_name: string::String,
    game_provider_name: string::String,
    random_seed: u64
}

public struct GameResult has key, store {
    id: UID,
    win_multiplier: u64,
    win_amount: u64,
    stake_amount: u64,
    symbols: vector<u8>
}

public struct GAME_PROVIDER has drop {}

// Initialize the admin capabilities to the deployer of the contract
// initialize the gameprovider registry
fun init(otw: GAME_PROVIDER, ctx: &mut TxContext) {
    assert!(types::is_one_time_witness(&otw)); // Check OTW
    transfer::transfer(
        GameProviderCap { id: object::new(ctx) },
        ctx.sender()
    );
    let registryObj = GameProviderRegistry {
        id: object::new(ctx),
        providerMap: vec_map::empty()
    };
    transfer::share_object(registryObj);
}

#[test_only]
public fun test_init(ctx: &mut TxContext){
    let otw = GAME_PROVIDER {};
    init(otw, ctx);
}

// Shared: start game round
#[allow(lint(public_random))]
public fun start_game_round(playerRegistration: &registration::PlayerRegistration, gameProvider: &mut GameProvider, 
gameName: string::String, stake: coin::Coin<SUI>, r: &random::Random, ctx: &mut TxContext): GameRound {
    let GameProvider { id: _, name: game_provider_name, treasury, games } = gameProvider;
    assert!(games.contains(gameName), EGameDoesNotExist);

    let gameProviderName: string::String = *game_provider_name;
    let gameName: string::String = *&gameName;

    // Find the game (type needs to be static)
    let gameObj = bag::borrow<string::String, slotty_cubes::SlottyCubes>(games, gameName);

    // Check if the treasury can fund this game
    let max_payout_factor = slotty_cubes::get_max_payout_factor(gameObj);
    assert!(treasury::can_cover_stake(treasury, &stake, max_payout_factor), EInsufficientFundsInTreasury);

    // Move the stake to the treasury
    let stake = treasury::stake(treasury, stake);

    // Generate randomness
    let mut generator = random::new_generator(r, ctx);
    let random_seed = generator.generate_u64();

    // Return game round
    GameRound {
        id: object::new(ctx),
        player_registration_id: registration::get_registration_id(playerRegistration),
        stake: stake,
        game_name: gameName,
        game_provider_name: gameProviderName,
        random_seed
    }

}

// Shared: settle game round
#[allow(lint(self_transfer))]
public fun settle_game_round(playerRegistration: &registration::PlayerRegistration, 
game_round: GameRound, gameProvider: &mut GameProvider, ctx: &mut TxContext): GameResult {
    let GameProvider { id: _, name: _, treasury, games } = gameProvider;

    // Complete the round
    let GameRound { id: game_round_id, player_registration_id, stake, game_name, game_provider_name: _, random_seed} = game_round;

    // Verify it is the correct player
    assert!(player_registration_id == registration::get_registration_id(playerRegistration));

    std::debug::print(&game_name);
    if (game_name == string::utf8(b"Slotty Cubes")){
        // Find the game (type needs to be static)
        let gameObj = bag::borrow<string::String, slotty_cubes::SlottyCubes>(games, game_name);
        let slottyGameResult = slotty_cubes::get_result(gameObj, random_seed);
        let (win_multiplier, symbols) = slotty_cubes::get_result_details(slottyGameResult);
        let stake_amount = treasury::get_stake_amount(&stake);

        let winnings = treasury::claim_winnings(treasury, stake, win_multiplier, ctx);
        let mut win_amount = 0;
        
        option::destroy!(winnings, |x| {
            win_amount = x.value();
            std::debug::print(&string::utf8(b"Transffering sui coin"));
            std::debug::print(&x.value());
            std::debug::print(&ctx.sender());
            transfer::public_transfer(x, ctx.sender());
        });
        object::delete(game_round_id);
        GameResult {
            id: object::new(ctx),
            win_multiplier,
            win_amount: win_amount,
            stake_amount,
            symbols
        }

    }
    else {
        abort EGameDoesNotExist
    }

}

// Shared: get game round info
public fun get_stake_amount(game_round: &GameRound): u64 {
    game_round.stake.get_stake_amount()
}

// Test only: get rand
#[test_only]
public fun get_rand(game_round: &GameRound): u64 {
    game_round.random_seed
}


// Admin: create new game provider with the specified properties
public fun create_new_game_provider(_: &GameProviderCap, registry: &mut GameProviderRegistry, name: string::String, ctx: &mut TxContext) {
    // Check the registry
    let GameProviderRegistry { id: _, providerMap } = registry;
    assert!(vec_map::contains(providerMap, &name) == false, EGameProviderAlreadyExists);

    // Init treasury
    let treasury = treasury::create_empty_treasury();

    // Create game provider
    let game_provider_id = object::new(ctx);
    let game_provider_id_copy = *object::uid_as_inner(&game_provider_id);
    let gameProvider = GameProvider {
        id: game_provider_id,
        name,
        treasury,
        games: bag::new(ctx),
    };
    transfer::share_object(gameProvider);

    // Save the game provider in the registry
    let gameProviderId = game_provider_id_copy;
    vec_map::insert(providerMap, name, gameProviderId);
}

// Admin: add game to the game provider
public fun add_slotty_cubes(_: &GameProviderCap, gameProvider: &mut GameProvider, game: slotty_cubes::SlottyCubes){
    let GameProvider { id: _, name, treasury: _, games } = gameProvider;
    assert!(name == string::utf8(b"Slotty"), EIncompatibleGameProvider); // slotty cubes is owned by Slotty
    
    let gameName = slotty_cubes::get_name(&game);
    bag::add(games, gameName, game)
}

// Shared: get all game providers
public fun get_all_game_providers(registry: &GameProviderRegistry): vec_map::VecMap<string::String, ID> {
    registry.providerMap
}

// Shared: check if a game exists
public fun has_game(game_provider: &GameProvider, game_name: string::String): bool {
    game_provider.games.contains(game_name)
}

// Admin: deposit
public fun deposit(_: &GameProviderCap, game_provider: &mut GameProvider, deposit: coin::Coin<SUI>){
    treasury::deposit(&mut game_provider.treasury, deposit);
}

// Admin: get the current balance
public fun get_current_balance(_: &GameProviderCap, game_provider: &GameProvider): u64 {
    treasury::get_current_balance(&game_provider.treasury)
}

// Shared: game round details
public fun get_game_result_details(game_result: &GameResult): (vector<u8>, u64, u64, u64) {
    (
        game_result.symbols,
        game_result.win_multiplier,
        game_result.win_amount,
        game_result.stake_amount
    )
}