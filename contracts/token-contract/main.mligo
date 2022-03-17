#include "./interface.mligo"
#include "./entrypoints/mint.mligo"
#include "./entrypoints/transfer.mligo"
#include "./entrypoints/receive.mligo"

let main (param: entrypoints * storage): operation list * storage =
    let (p, { data = data; ledger = ledger }) = param in
    match p with
    | Mint n -> ([]: operation list), mint (n, (data, ledger))
    | Transfer n -> transfer (n, (data, ledger))
    | Receive n -> ([]: operation list), receive (n, (data, ledger))