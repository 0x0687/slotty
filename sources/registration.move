module slotty::registration;

public struct PlayerRegistration has key, store {
    id: UID,
}

public fun get_id(registration: &PlayerRegistration): &ID {
    object::uid_as_inner(&registration.id)
}

#[allow(lint(self_transfer))]
public fun register(ctx: &mut TxContext) {
    let playerRegistration = PlayerRegistration { 
        id: object::new(ctx)
     };
     transfer::public_transfer(playerRegistration, ctx.sender());
}