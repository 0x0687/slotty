module slotty::registration;

public struct PlayerRegistration has key, store {
    id: UID,
}

#[allow(lint(self_transfer))]
public fun register(ctx: &mut TxContext) {
    let playerRegistration = PlayerRegistration { 
        id: object::new(ctx)
     };
     transfer::public_transfer(playerRegistration, ctx.sender());
}

public fun get_registration_id(registration: &PlayerRegistration): ID {
    registration.id.to_inner()
}