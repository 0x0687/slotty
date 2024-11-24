import { getFullnodeUrl, SuiClient } from '@mysten/sui/client';
import { Transaction } from '@mysten/sui/transactions';
import { Ed25519Keypair } from '@mysten/sui/keypairs/ed25519';
import { bcs } from '@mysten/sui/bcs';
import { config } from 'dotenv';
import { abort } from 'process';

const secretKey = "suiprivkey1qqhj5yhqd5tw4crt0jaq7tyfnzpcg86mrsswcxa40wta6rtp5dc4j7lpcv5"; // sui keytool convert

// use getFullnodeUrl to define Devnet RPC location
const rpcUrl = getFullnodeUrl("localnet");
 
// create a client
const client = new SuiClient({ url: rpcUrl });

const keypair = Ed25519Keypair.fromSecretKey(secretKey);
console.log(`Running for account: ${keypair.toSuiAddress()}`)
config();
const PACKAGE_ID = process.env.PACKAGE_ID || "";
const GAME_PROVIDER_ID = process.env.GAME_PROVIDER_ID || "";
const PLAYER_REGISTRATION_ID = process.env.PLAYER_PLAYER_REGISTRATION_ID || "";

const STAKE = 1000000000;
const tx = new Transaction();
const [coin] = tx.splitCoins(tx.gas, [STAKE]);
const [gameround] = tx.moveCall({
	target: `${PACKAGE_ID}::game_provider::start_game_round`,
	arguments: [
		tx.object(PLAYER_REGISTRATION_ID),
        tx.object(GAME_PROVIDER_ID),
        tx.pure.string("Slotty Cubes"),
        coin,
        tx.object('0x8') // random
	],
});
tx.setGasBudget(STAKE + 10000000)
tx.transferObjects([gameround], keypair.toSuiAddress());

const result = await client.signAndExecuteTransaction({ signer: keypair, transaction: tx });
await client.waitForTransaction({ digest: result.digest });
console.log(result);

const ownedObjects = await client.getOwnedObjects({
    owner: keypair.toSuiAddress(),
    options: {
        showType: true
    }
});

for (let index = 0; index < ownedObjects.data.length; index++) {
    const obj = ownedObjects.data[index];
    if (obj.data?.type && obj.data.type == `${PACKAGE_ID}::game_provider::GameRound`){
        console.log(`Settling game round: ${obj.data.objectId}`)
        const tx2 = new Transaction();
        const [gameresult] = tx2.moveCall({
        	target: `${PACKAGE_ID}::game_provider::settle_game_round`,
        	arguments: [
        		tx2.object(PLAYER_REGISTRATION_ID),
                tx2.object(obj.data.objectId),
                tx2.object(GAME_PROVIDER_ID),
        	],
        })
        tx2.transferObjects([gameresult], keypair.toSuiAddress());
        const result2 = await client.signAndExecuteTransaction({ signer: keypair, transaction: tx2 });
        await client.waitForTransaction({ digest: result2.digest });
        console.log(result2);
    }
}