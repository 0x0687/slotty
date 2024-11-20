module slotty::gameprovider;

use std::string;
use slotty::treasury;
use slotty::slotty_cubes;
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

public struct GameResult has drop, store {
    win_multiplier: u64,
    win_amount: u64,
    stake_amount: u64,
    symbols: vector<u8>
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

    // Create game round
    let gameRoundObj = GameRound {
        stake: stake,
        game_name: gameProviderName,
        game_provider_name: gameName,
        random_seed
    };

    // Save game round
    let playerId = registration::get_id(playerRegistration);
    table::add(game_rounds, *playerId, gameRoundObj);
}

// Shared: settle game round
#[allow(lint(self_transfer))]
public fun settle_game_round(playerRegistration: &registration::PlayerRegistration, gameProvider: &mut GameProvider, ctx: &mut TxContext): GameResult {
    let GameProvider { id: _, name: _, treasury, games, game_rounds } = gameProvider;
    // Check if the player has a round active
    assert!(table::contains(game_rounds, *registration::get_id(playerRegistration)) == true, ENoActiveGameRound);

    // Complete the round
    let GameRound { stake, game_name, game_provider_name: _, random_seed} = table::remove(game_rounds, *registration::get_id(playerRegistration));

    if (game_name == string::utf8(b"Slotty Cubes")){
        // Find the game (type needs to be static)
        let gameObj = bag::borrow<string::String, slotty_cubes::SlottyCubes>(games, game_name);
        let slottyGameResult = slotty_cubes::get_result(gameObj, random_seed);
        let (win_multiplier, symbols) = slotty_cubes::get_result_details(&slottyGameResult);
        let stake_amount = treasury::get_stake_amount(&stake);

        let winnings = treasury::claim_winnings(treasury, stake, win_multiplier, ctx);
        let mut win_amount = 0;
        option::destroy!(winnings, |x| {
            win_amount = x.value();
            transfer::public_transfer(x, ctx.sender());
        });
        GameResult {
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
public fun add_slotty_cubes(_: &GameProviderCap, gameProvider: &mut GameProvider, game: slotty_cubes::SlottyCubes){
    let GameProvider { id: _, name, treasury: _, games, game_rounds: _ } = gameProvider;
    assert!(name == string::utf8(b"Slotty"), EIncompatibleGameProvider); // slotty cubes is owned by Slotty
    
    let gameName = slotty_cubes::get_name(&game);
    bag::add(games, gameName, game)
}