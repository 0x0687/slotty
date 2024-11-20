
#[test_only]
module slotty::treasury_tests;

use sui::test_scenario;
use sui::sui::SUI;
use sui::coin;
use slotty::treasury;

#[test]
fun treasury_unit_tests() {
    let addr = @0xA;
    let mut scenario = test_scenario::begin(addr);
    {
        // Create empty treasury
        let mut treasuryObj = treasury::create_empty_treasury();
        // Deposit 1000 MIST 
        let coin = coin::mint_for_testing<SUI>(1000, scenario.ctx());
        treasury::deposit(&mut treasuryObj, coin);
        // Verify the deposit
        let currentAmount = treasury::get_current_balance(&treasuryObj);
        assert!(currentAmount == 1000);
        // Place a stake
        let stakeCoin = coin::mint_for_testing<SUI>(100, scenario.ctx());
        let stake = treasury::stake(&mut treasuryObj, stakeCoin);
        // Verify the new amount
        let currentAmount = treasury::get_current_balance(&treasuryObj);
        assert!(currentAmount == 1100);
        // Claim zero winnings
        let zeroWinning = treasury::claim_winnings(&mut treasuryObj, stake, 0, scenario.ctx());
        assert!(zeroWinning.is_none());
        zeroWinning.destroy_none();
        // Place a second stake
        let stakeCoin = coin::mint_for_testing<SUI>(100, scenario.ctx());
        let stake = treasury::stake(&mut treasuryObj, stakeCoin);
        // Verify the new amount
        let currentAmount = treasury::get_current_balance(&treasuryObj);
        assert!(currentAmount == 1200);
        // Claim 10x winnings
        let bigWinning = treasury::claim_winnings(&mut treasuryObj, stake, 10, scenario.ctx());
        assert!(bigWinning.is_some());
        bigWinning.destroy!(|x|{
            assert!(x.value() == 1000);
            coin::burn_for_testing(x);
        });
        // Withdraw and burn remaining amount
        let coin = treasury::withdraw(&mut treasuryObj, 200, scenario.ctx());
        let _amount = coin.burn_for_testing();
        treasury::destroy_treasury(treasuryObj);
    };    
    scenario.end();
}

#[test]
fun treasury_cover_requirement_tests() {
    let addr = @0xA;
    let mut scenario = test_scenario::begin(addr);
    {
        // Create empty treasury
        let mut treasuryObj = treasury::create_empty_treasury();
        // Deposit 1000 MIST 
        let coin = coin::mint_for_testing<SUI>(1000, scenario.ctx());
        treasury::deposit(&mut treasuryObj, coin);
        // Stake of 100
        let coin = coin::mint_for_testing<SUI>(100, scenario.ctx());
        assert!(treasury::can_cover_stake(&treasuryObj, &coin, 0) == true);
        assert!(treasury::can_cover_stake(&treasuryObj, &coin, 1) == true);
        assert!(treasury::can_cover_stake(&treasuryObj, &coin, 5) == true);
        assert!(treasury::can_cover_stake(&treasuryObj, &coin, 10) == true);
        assert!(treasury::can_cover_stake(&treasuryObj, &coin, 11) == false);
        coin.burn_for_testing();
        // Withdraw and burn amount
        let coin = treasury::withdraw(&mut treasuryObj, 1000, scenario.ctx());
        coin.burn_for_testing();
        treasury::destroy_treasury(treasuryObj);
    };    
    scenario.end();
}