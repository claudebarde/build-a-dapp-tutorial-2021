type token_id = nat

type token = token_id ticket 

type transfer_params = 
[@layout:comb]
{
    token_id: token_id;
    recipient: address;
    token_amount: nat;
}

type entrypoints =
| Mint of nat
| Transfer of transfer_params
| Receive of nat ticket

type data =
[@layout:comb]
{
    admin: address;
    native_token: token_id;
}

type ledger = ((token_id * address), token) big_map

type storage =
{
    data: data;
    ledger: ledger;
}