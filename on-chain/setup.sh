# Start the local sui network
RUST_LOG="off,sui_node=info" sui start --with-faucet --force-regenesis

# build and run tests
sui move test

# get some coin
sui client faucet

# publish package
eval $(sui client publish --json | jq -r '
  .objectChanges[] |
  if .type == "published" then
    "PACKAGE_ID=\(.packageId)"
  elif .objectType | contains("::game_provider::GameProviderCap") then
    "GAME_PROVIDER_CAP_ID=\(.objectId)"
  elif .objectType | contains("::game_provider::GameProviderRegistry") then
    "GAME_PROVIDER_REGISTRY_ID=\(.objectId)"
  else empty end
')

# register the player
eval $(sui client ptb --move-call $PACKAGE_ID::registration::register --json | jq -r '
.objectChanges[] | 
select(.type == "created") | 
"PLAYER_PLAYER_REGISTRATION_ID=\(.objectId)"
')

# create the slotty game provider
eval $(sui client ptb --move-call $PACKAGE_ID::game_provider::create_new_game_provider @$GAME_PROVIDER_CAP_ID @$GAME_PROVIDER_REGISTRY_ID '"Slotty"' --json | jq -r '
.objectChanges[] | 
select(.type == "created") | 
"GAME_PROVIDER_ID=\(.objectId)"
')

# add the game
sui client ptb \
--assign reels vector[vector[0, 1, 2],vector[0, 1, 2],vector[0, 1, 2],vector[0, 1, 2],vector[0, 1, 2]] \
--assign accepted_stakes vector[1000000000] \
--assign max_payout_factor 10 \
--move-call $PACKAGE_ID::slotty_cubes::create_game '"Slotty Cubes"' reels accepted_stakes max_payout_factor \
--assign game \
--move-call $PACKAGE_ID::game_provider::add_slotty_cubes @$GAME_PROVIDER_CAP_ID @$GAME_PROVIDER_ID game \
--json

# fund the treasury
sui client ptb \
--split-coins gas [10000000000] \
--assign deposit_coin \
--move-call $PACKAGE_ID::game_provider::deposit @$GAME_PROVIDER_CAP_ID @$GAME_PROVIDER_ID deposit_coin \
--json

# write the variables to .env file
cat <<EOF > .env
PACKAGE_ID=$PACKAGE_ID
GAME_PROVIDER_CAP_ID=$GAME_PROVIDER_CAP_ID
GAME_PROVIDER_REGISTRY_ID=$GAME_PROVIDER_REGISTRY_ID
PLAYER_PLAYER_REGISTRATION_ID=$PLAYER_PLAYER_REGISTRATION_ID
GAME_PROVIDER_ID=$GAME_PROVIDER_ID
EOF
