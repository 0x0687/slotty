import { SuiGraphQLClient } from '@mysten/sui/graphql';
import { graphql } from '@mysten/sui/graphql/schemas/2024.4';
 
const gqlClient = new SuiGraphQLClient({
	url: 'https://sui-testnet.mystenlabs.com/graphql',
});
 
const chainIdentifierQuery = graphql(`
    query DynamicField {
    object(
        address: "0x3101d49799df770973c6fb1bed90d5b3faf8360025704e0a3fb27c97748d61c7"
    ) {
        dynamicField(
        name: {
            type: "0x2::kiosk::Listing",
            bcs: "NLArx1UJguOUYmXgNG8Pv8KbKXLjWtCi6i0Yeq1VhfwA",
        }
        ) {
        ...DynamicFieldSelect
        }
    }
    }

    fragment DynamicFieldSelect on DynamicField {
    name {
        ...MoveValueFields
    }
    value {
        ...DynamicFieldValueSelection
    }
    }

    fragment DynamicFieldValueSelection on DynamicFieldValue {
    __typename
    ... on MoveValue {
        ...MoveValueFields
    }
    ... on MoveObject {
        hasPublicTransfer
        contents {
        ...MoveValueFields
        }
    }
    }

    fragment MoveValueFields on MoveValue {
    type {
        repr
    }
    data
    bcs
    }
`);
 
async function getChainIdentifier() {
	const result = await gqlClient.query({
		query: chainIdentifierQuery,
	});
 
	return result.data;
}

console.log(await getChainIdentifier())