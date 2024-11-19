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

public fun can_cover_stake(treasury: &Treasury, stake: &coin::Coin<SUI>, max_payout_factor: u64): bool {
    treasury.balance.value() > stake.value() * max_payout_factor
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