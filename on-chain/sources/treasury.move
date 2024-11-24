module slotty::treasury;

use sui::balance;
use sui::sui::SUI;
use sui::coin;

public struct Treasury has store {
    balance: balance::Balance<SUI> // Only works with SUI right now, can extend to other coins later
}

public struct Stake has store {
    amount: u64
}

public fun create_empty_treasury (): Treasury{
    Treasury {
        balance: balance::zero<SUI>()
    }
}

public fun deposit(treasury: &mut Treasury, deposit: coin::Coin<SUI>){
    treasury.balance.join(deposit.into_balance());
}

public fun withdraw(treasury: &mut Treasury, amount: u64, ctx: &mut TxContext): coin::Coin<SUI> {
    let balance = treasury.balance.split(amount);
    balance.into_coin(ctx)
}

public fun get_current_balance(treasury: &Treasury): u64{
    treasury.balance.value()
}

public fun can_cover_stake(treasury: &Treasury, stake: &coin::Coin<SUI>, max_payout_factor: u64): bool {
    treasury.balance.value() >= stake.value() * max_payout_factor
}

public fun claim_winnings(treasury: &mut Treasury, stake: Stake, winning_multiplier: u64, ctx: &mut TxContext): Option<coin::Coin<SUI>> {
    let Stake { amount } = stake;
    if (winning_multiplier == 0){
        option::none()
    }
    else {
        let coin = treasury.balance.split(amount * winning_multiplier).into_coin(ctx);
        option::some(coin)
    }
}

public fun stake(treasury: &mut Treasury, stake: coin::Coin<SUI>): Stake {
    let Treasury { balance } = treasury;

    let stakeObj = Stake {
        amount: stake.value()
    };
    
    // Transfer the stake value into the treasury balance
    balance::join<SUI>(balance, stake.into_balance());
    stakeObj
}

public fun get_stake_amount(stake: &Stake): u64 {
    stake.amount
}


public fun destroy_treasury(treasury: Treasury) {
    let Treasury {balance} = treasury;
    balance.destroy_zero();
}