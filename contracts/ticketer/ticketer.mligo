type ticket_type = string

type ticket_param =
[@layout:comb]
{
    ticket_amount: nat;
    ticket_owner: address;
    ticket_type: ticket_type;
}

type get_balance_param = address * (ticket_type * ticket_param contract)

type storage_data = {
    ticket_validity: int;
    valid_ticket_types: (ticket_type, tez) big_map;
}

type ticket_val = timestamp * ticket_type ticket
type tickets = (address * ticket_type, ticket_val) big_map

type storage =
{
    data: storage_data;
    tickets: tickets
}

type entrypoint =
| Buy_tickets of ticket_param
| Redeem_ticket of ticket_type 
| Get_balance of get_balance_param

(* When users want to buy tickets *)
let buy_tickets (p, (s, tickets): ticket_param * (storage_data * tickets)): storage =
    let { 
            ticket_amount = ticket_amount; 
            ticket_owner = _ticket_owner; 
            ticket_type = ticket_type 
        } = p in
    (* Checks if ticket amount is not zero *)
    if ticket_amount < 1n
    then (failwith "INVALID_TICKET_AMOUNT": storage)
    else
        (* Checks if ticket type is valid *)
        let price_per_type: tez = 
            match Big_map.find_opt ticket_type s.valid_ticket_types with
            | None -> (failwith "INVALID_TICKET_TYPE": tez)
            | Some a -> a in
        (* Checks if amount is not zero and matches ticket amount * tez for ticket type *)
        if Tezos.amount = 0tez || Tezos.amount <> ticket_amount * price_per_type
        then (failwith "INVALID_AMOUNT": storage)
        else
            (* Checks if user already has tickets *)
            let (ticket, tickets_map) = Big_map.get_and_update (Tezos.sender, ticket_type) (None: ticket_val option) tickets in
            let new_ticket = 
                match ticket with
                | None -> 
                    (* If no previous tickets, a new ticket is issued *)
                    Tezos.create_ticket ticket_type ticket_amount
                | Some t ->
                    (* If previous tickets, a new ticket is issued and joined with the previous one *)
                    let new_ticket = Tezos.create_ticket ticket_type ticket_amount in
                    (match Tezos.join_tickets (t.1, new_ticket) with
                    | None -> (failwith "UNJOINABLE_TICKETS": ticket_type ticket)
                    | Some j_t -> j_t)
            in
            (* Saves new tickets *)
            let (_, new_tickets) = Big_map.get_and_update (Tezos.sender, ticket_type) (Some (Tezos.now, new_ticket)) tickets_map in

            { data = s; tickets = new_tickets }

(* When users want to use the tickets they bought *)
let redeem_ticket (ticket_type, (s, tickets): ticket_type * (storage_data * tickets)): storage =
    (* Finds user's tickets in storage *)
    let (ticket, tickets_map) = Big_map.get_and_update (Tezos.sender, ticket_type) (None: ticket_val option) tickets in
    let new_tickets = 
        match ticket with
        | None -> (failwith "NO_TICKETS": (address * ticket_type, ticket_val) big_map)
        | Some t ->
            (* Checks tickets validity *)
            let (ticket_creation, ticket) = t in
            if ticket_creation + s.ticket_validity < Tezos.now
            then (failwith "INVALID_TICKETS": (address * ticket_type, ticket_val) big_map)
            else
                (* Reads the user's tickets *)
                let ((_,(_, amt)),ticket) = Tezos.read_ticket ticket in
                if amt = 0n
                then (failwith "ZERO_AMOUNT_TICKET": (address * ticket_type, ticket_val) big_map)
                else if amt = 1n
                then
                    (* Remove the binding in the big_map altogether *)
                    tickets_map
                else
                    (* Split user's tickets to deduct 1 ticket *)
                   (match Tezos.split_ticket ticket ((abs (amt - 1n)), 1n) with
                    | None -> (failwith "UNSPLITTABLE_TICKET": (address * ticket_type, ticket_val) big_map)
                    | Some t -> 
                        (* Saves new ticket in storage *)
                        let (_, new_tickets_map) = 
                            Big_map.get_and_update (Tezos.sender, ticket_type) (Some (ticket_creation, t.0)) tickets_map in
                        new_tickets_map)
    in

    { data = s; tickets = new_tickets }

(* When a contract wants to know a user's balance for a certain ticket type *)
let get_balance (p, (s, tickets): get_balance_param * (storage_data * tickets)): operation list * storage =
    let (owner, (ticket_type, callback)) = p in
    (* Finds the ticket in the storage *)
    let (ticket, tickets_map) = Big_map.get_and_update (owner, ticket_type) (None: ticket_val option) tickets in
    let (amt, ticket_opt): (nat * ticket_val option) =
        match ticket with
        | None -> 0n, (None: ticket_val option)
        | Some t ->
            let (validity, ticket) = t in 
            (* Reads the ticket *)
            let ((_, (_, amt)), ticket) = Tezos.read_ticket ticket in
            (amt, (Some (validity, ticket)))
    in
    (* Returns the balance *)
    let param: ticket_param = {
        ticket_amount = amt;
        ticket_owner = owner;
        ticket_type = ticket_type;
    } in
    (* Reset the ticket in the big_map *)
    let (_, tickets_map) = Big_map.get_and_update (owner, ticket_type) ticket_opt tickets_map in

    [Tezos.transaction param 0tez callback],
    { data = s; tickets = tickets_map }

let main (param: entrypoint * storage): operation list * storage =
    let (p, { data = s; tickets = tickets }) = param in
    match p with
    | Buy_tickets n -> 
        ([]: operation list), buy_tickets (n, (s, tickets))
    | Redeem_ticket n -> 
        ([]: operation list), redeem_ticket (n, (s, tickets))
    | Get_balance n -> 
        get_balance (n, (s, tickets))