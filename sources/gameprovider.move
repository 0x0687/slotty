module slotty::gameprovider;

use std::string;
use slotty::treasury;
use slotty::pandoras_cubes;
use slotty::registration;
use sui::table;
use sui::bag;
use sui::types;
use sui::coin;
use sui::sui::SUI;
use sui::random;


const EIncompatibleGameProvider: u64 = 1;
const EGameProviderAlreadyExists: u64 = 2;
const EInsufficientFundsInTreasury: u64 = 3;
const ENoActiveGameRound: u64 = 4;

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
    games: bag::Bag,
    game_rounds: table::Table<ID, GameRound>
}

public struct GameProviderRegistry has key {
    id: UID,
    providerMap: table::Table<string::String, ID>
}

public struct GameRound has store {
    stake: treasury::Stake,
    game_name: string::String,
    game_provider_name: string::String,
    random_seed: u64
}

public struct GAMEPROVIDER has drop {}

// Initialize the admin capabilities to the deployer of the contract
// initialize the gameprovider registry
fun init(otw: GAMEPROVIDER, ctx: &mut TxContext) {
    assert!(types::is_one_time_witness(&otw)); // Check OTW
    transfer::transfer(
        GameProviderCap { id: object::new(ctx) },
        ctx.sender()
    );
    let registryObj = GameProviderRegistry {
        id: object::new(ctx),
        providerMap: table::new(ctx)
    };
    transfer::share_object(registryObj);
}

// Shared: start game round
#[allow(lint(public_random))]
public fun start_game_round(playerRegistration: &registration::PlayerRegistration, gameProvider: &mut GameProvider, gameName: string::String, stake: coin::Coin<SUI>, r: &random::Random, ctx: &mut TxContext) {
    let GameProvider { id: _, name: game_provider_name, treasury, games, game_rounds } = gameProvider;
    assert!(games.contains(gameName), 0);

    let gp_name_copy: string::String = *game_provider_name;
    let game_name_copy: string::String = *&gameName;

    // Find the game (type needs to be static)
    let gameObj = bag::borrow<string::String, pandoras_cubes::PandorasCubes>(games, gameName);

    // Check if the treasury can fund this game
    let max_payout_factor = pandoras_cubes::get_max_payout_factor(gameObj);
    assert!(treasury::can_cover_stake(treasury, &stake, max_payout_factor), EInsufficientFundsInTreasury);

    // Move the stake to the treasury
    let stake = treasury::stake(treasury, stake);

    // Generate randomness
    let mut generator = random::new_generator(r, ctx);
    let random_seed = generator.generate_u64();

    // Create game round
    let gameRoundObj = GameRound {
        stake: stake,
        game_name: game_name_copy,
        game_provider_name: gp_name_copy,
        random_seed
    };

    // Save game round
    let playerId = registration::get_id(playerRegistration);
    table::add(game_rounds, *playerId, gameRoundObj);
}

// Shared: settle game round
public fun settle_game_round(playerRegistration: &registration::PlayerRegistration, gameProvider: &mut GameProvider, ctx: &mut TxContext) {
    let GameProvider { id: _, name: _, treasury, games: _, game_rounds } = gameProvider;
    // Check if the player has a round active
    assert!(table::contains(game_rounds, *registration::get_id(playerRegistration)) == true, ENoActiveGameRound);

    // Complete the round
    let game_round = table::borrow_mut(game_rounds, *registration::get_id(playerRegistration));
    

}

// Admin: create new game provider with the specified properties
public fun create_new_game_provider(_: &GameProviderCap, registry: &mut GameProviderRegistry, name: string::String, ctx: &mut TxContext) {
    // Check the registry
    let GameProviderRegistry { id: _, providerMap } = registry;
    assert!(table::contains(providerMap, name) == false, EGameProviderAlreadyExists);

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
        game_rounds: table::new(ctx)
    };
    transfer::share_object(gameProvider);

    // Save the game provider in the registry
    let gameProviderId = game_provider_id_copy;
    table::add(providerMap, name, gameProviderId);
}

// Admin: add game to the game provider
public fun add_pandoras_cubes(_: &GameProviderCap, gameProvider: &mut GameProvider, game: pandoras_cubes::PandorasCubes){
    let GameProvider { id: _, name, treasury: _, games, game_rounds: _ } = gameProvider;
    assert!(name == string::utf8(b"RedPanda"), EIncompatibleGameProvider); // Pandoras cubes is owned by redpanda
    
    let gameName = pandoras_cubes::get_name(&game);
    bag::add(games, gameName, game)
}