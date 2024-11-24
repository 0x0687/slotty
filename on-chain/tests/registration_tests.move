
#[test_only]
module slotty::registration_tests;

use sui::test_scenario;
use slotty::registration;

#[test]
fun register_success() {
    let addr1 = @0xA;

    let mut scenario = test_scenario::begin(addr1);
    
    // Create a registration and store it
    {
        registration::register(test_scenario::ctx(&mut scenario));
    };

    // Retrieve it and check it
    test_scenario::next_tx(&mut scenario, addr1);
    {
        // Taking the object from the sender is already a check. It errors if no object is present.
        let registration = test_scenario::take_from_sender<registration::PlayerRegistration>(&scenario);
        test_scenario::return_to_sender(&scenario, registration);
    };

    // Cleans up the scenario object
    test_scenario::end(scenario);
}