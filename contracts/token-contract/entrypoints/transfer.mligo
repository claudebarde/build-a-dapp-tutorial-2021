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