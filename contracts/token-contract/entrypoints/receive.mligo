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


    