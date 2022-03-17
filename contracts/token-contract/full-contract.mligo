# 1 "./contract/main.mligo"

# 1 "./contract/./interface.mligo" 1
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
# 2 "./contract/main.mligo" 2

# 1 "./contract/./entrypoints/mint.mligo" 1
let mint (token_amount, (data, ledger): nat * (data * ledger)): storage =
    (* creates new tokens *)
    if Tezos.sender <> data.admin
    then (failwith "UNAUTHORIZDED_ACTION": storage)
    else
        (* finds if admin already has a balance in the token *)
        let (token, ledger_1): token option * ledger =
            Big_map.get_and_update (data.native_token, Tezos.sender) (None: token option) ledger in
        let (_, ledger_2): token option * ledger = 
            match token with
            | None -> 
                (* admin didn't have a previous balance *)
                let new_token: token = Tezos.create_ticket data.native_token token_amount in
                Big_map.get_and_update (data.native_token, Tezos.sender) (Some new_token) ledger_1
            | Some op_t ->
                (* admin already had a balance *)
                (* creates a new token *)
                let new_token: token = Tezos.create_ticket data.native_token token_amount in
                (* join the current token from the ledger with the new one *)
                let joined_token: token =  
                    match Tezos.join_tickets (op_t, new_token) with
                    | None -> (failwith "UNJOINABLE_TICKETS": token)
                    | Some joined -> joined in
                (* update the ledger with new token *)
                Big_map.get_and_update (data.native_token, Tezos.sender) (Some joined_token) ledger_1
            in

        { data = data; ledger = ledger_2 }
# 3 "./contract/main.mligo" 2

# 1 "./contract/./entrypoints/transfer.mligo" 1
let transfer ((p, (data, ledger)): (transfer_params * (data * ledger))): operation list * storage =
    (* finds sender in ledger *)
    let (sender_ticket, ledger_1) =
        Big_map.get_and_update (p.token_id, Tezos.sender) (None: token option) ledger in
    let (sender_balance, sender_token): nat * token =
        match sender_ticket with
        | None -> (failwith "NO_BALANCE": nat * token)
        | Some t -> 
            let ((_, (_, b)), tck) = Tezos.read_ticket t in
            b, tck 
    in
    (* checks if sender has enough balance *)
    if sender_balance < p.token_amount
    then (failwith "INSUFFICIENT_BALANCE": operation list * storage)
    else
        (* finds recipient in ledger *)
        let (recipient_ticket, ledger_2) =
            Big_map.get_and_update (p.token_id, p.recipient) (None: token option) ledger_1 in
        (* checks if recipient has previous token *)
        let recipient_token: token =
            match recipient_ticket with
            | None -> Tezos.create_ticket p.token_id 0n
            | Some t -> t
        in
        (* deducts token amount from sender's balance by splitting his ticket *)
        let (new_sender_token, amount_to_transfer) = 
            match Tezos.split_ticket sender_token (abs (sender_balance - p.token_amount), p.token_amount) with
            | None -> (failwith "FAILED_TO_SPLIT_TICKETS": token * token)
            | Some tcks -> tcks in
        (* adds token amount to recipient's balance by joining tickets *)
        let new_recipient_token =
            match Tezos.join_tickets (recipient_token, amount_to_transfer) with
            | None -> (failwith "FAILED_TO_JOIN_TICKETS": token)
            | Some t -> t in
        (* saves sender's token in the storage *)
        let (_, ledger_3) = 
            Big_map.get_and_update (p.token_id, Tezos.sender) (Some new_sender_token) ledger_2 in
        (* saves recipient's token in the storage *)
        let (_, ledger_4) = 
            Big_map.get_and_update (p.token_id, p.recipient) (Some new_recipient_token) ledger_3 in

        ([]: operation list), { data = data; ledger = ledger_4 }
# 4 "./contract/main.mligo" 2

# 1 "./contract/./entrypoints/receive.mligo" 1
let receive (token, (data, ledger): token * (data * ledger)): storage =
    (* received tokens are stored in the contract *)
    (* gets token id from received ticket *)
    let ((_, (token_id, _)), token_copy) = Tezos.read_ticket token in
    (* checks if previous balance is available *)
    let (token, ledger_2) =
        Big_map.get_and_update (token_id, data.admin) (None: token option) ledger in
    let (_, ledger_3) = 
        match token with
        | None -> (* no previous token *)
            Big_map.get_and_update (token_id, data.admin) (Some token_copy) ledger_2
        | Some t -> (* entry exists *)
            (match Tezos.join_tickets (t, token_copy) with
            | None -> (failwith "FAILED_TO_JOIN_TICKETS": token option * ledger)
            | Some j_t -> (* saves new token in ledger *)
                Big_map.get_and_update (token_id, data.admin) (Some j_t) ledger_2)
    in

    { data = data; ledger = ledger_3 }


    
# 5 "./contract/main.mligo" 2

let main (param: entrypoints * storage): operation list * storage =
    let (p, { data = data; ledger = ledger }) = param in
    match p with
    | Mint n -> ([]: operation list), mint (n, (data, ledger))
    | Transfer n -> transfer (n, (data, ledger))
    | Receive n -> ([]: operation list), receive (n, (data, ledger))
