<script lang="ts">
  import { onMount } from "svelte";
  import { TezosToolkit } from "@taquito/taquito";
  import type { ContractAbstraction, Wallet } from "@taquito/taquito";
  import { BeaconWallet } from "@taquito/beacon-wallet";
  import { NetworkType } from "@airgap/beacon-sdk";

  type UserTickets =
    | { ticketer: string; value: string; amount: number }
    | undefined;

  let Tezos: TezosToolkit;
  let wallet: BeaconWallet;
  let userAddress = "";
  let userTickets: UserTickets = undefined;
  let userTicketValidity: string;
  let ticketer: ContractAbstraction<Wallet>;
  let ticketerStorage: any;
  let loadingProfile = true;
  let loadingBuy = false;
  let loadingRedeem = false;

  const rpcUrl = "https://hangzhounet.api.tez.ie";
  const ticketerAddress = "KT1F5im2WKiqCZrs9EVC1qLNJhsCNCZ2Piks";

  const fetchUserTickets = async (
    address: string,
    ticketerAddress: string
  ): Promise<{ tickets: UserTickets; validity: string }> => {
    let tickets: UserTickets;
    let ticketsValidity = "";
    try {
      ticketer = await Tezos.wallet.at(ticketerAddress);
      ticketerStorage = await ticketer.storage();
      const result = await ticketerStorage.tickets.get({
        0: address,
        1: "standard"
      });
      if (result) {
        tickets = result[1];
        ticketsValidity = result[0];
      } else {
        tickets = undefined;
        ticketsValidity = "";
      }
    } catch (error) {
      console.log(error);
    }

    return { tickets, validity: ticketsValidity };
  };

  const connect = async () => {
    try {
      wallet = new BeaconWallet({
        name: "Ligo Tickets Tutorial",
        preferredNetwork: NetworkType.HANGZHOUNET
      });
      await wallet.requestPermissions({
        network: {
          type: NetworkType.HANGZHOUNET,
          rpcUrl
        }
      });
      Tezos.setWalletProvider(wallet);
      userAddress = await wallet.getPKH();
      const { tickets, validity } = await fetchUserTickets(
        userAddress,
        ticketerAddress
      );
      userTickets = tickets;
      userTicketValidity = validity;
    } catch (err) {
      console.error(err);
    } finally {
      loadingProfile = false;
    }
  };

  const disconnect = () => {
    wallet.client.destroy();
    wallet = undefined;
    userAddress = "";
  };

  const buyTickets = async (ticketAmount: number) => {
    loadingBuy = true;
    try {
      const pricePerTicket = await ticketerStorage.data.valid_ticket_types.get(
        "standard"
      );
      const op = await ticketer.methods
        .buy_tickets(ticketAmount, userAddress, "standard")
        .send({
          amount: pricePerTicket.toNumber() * ticketAmount,
          mutez: true
        });
      await op.confirmation();
      // refreshes the storage
      ticketerStorage = await ticketer.storage();
      // gets user's tickets
      const result = await ticketerStorage.tickets.get({
        0: userAddress,
        1: "standard"
      });
      if (result) {
        userTickets = result[1];
        userTicketValidity = result[0];
      } else {
        userTickets = undefined;
        userTicketValidity = "";
      }
    } catch (error) {
      console.log(error);
    } finally {
      loadingBuy = false;
    }
  };

  const redeemTicket = async () => {
    loadingRedeem = true;
    try {
      const op = await ticketer.methods.redeem_ticket("standard").send();
      await op.confirmation();
      // refreshes the storage
      ticketerStorage = await ticketer.storage();
      // gets user's tickets
      const result = await ticketerStorage.tickets.get({
        0: userAddress,
        1: "standard"
      });
      if (result) {
        userTickets = result[1];
        userTicketValidity = result[0];
      } else {
        userTickets = undefined;
        userTicketValidity = "";
      }
    } catch (error) {
      console.log(error);
    } finally {
      loadingRedeem = false;
    }
  };

  onMount(async () => {
    Tezos = new TezosToolkit(rpcUrl);
    wallet = new BeaconWallet({
      name: "Ligo Tickets Tutorial",
      preferredNetwork: NetworkType.HANGZHOUNET
    });
    const activeAccount = await wallet.client.getActiveAccount();
    if (activeAccount) {
      Tezos.setWalletProvider(wallet);
      userAddress = activeAccount.address;
      const { tickets, validity } = await fetchUserTickets(
        userAddress,
        ticketerAddress
      );
      userTickets = tickets;
      userTicketValidity = validity;
      loadingProfile = false;
    }
  });
</script>

<style lang="scss">
  $tezos-blue: #2e7df7;

  .container {
    font-size: 20px;
    max-width: 50%;

    .title {
      color: $tezos-blue;
      font-size: 80px;
      margin: 20px;
    }

    .subtitle {
      font-size: 30px;
      color: #333;
      margin: 10px;
    }

    button {
      appearance: none;
      border: solid 2px $tezos-blue;
      border-radius: 5px;
      background-color: white;
      padding: 20px;
      font-size: 20px;
      color: $tezos-blue;
      transition: 0.3s;
      cursor: pointer;
      outline: none;

      &:hover {
        color: white;
        background-color: $tezos-blue;
      }
    }

    a {
      color: $tezos-blue;
      text-decoration: underline;
    }
  }

  .loading {
    background: linear-gradient(92deg, #dce8f9, #2e7df7);
    background-size: 400% 400%;
    color: white !important;
    border: solid 2px white !important;
    -webkit-animation: loading 2s ease infinite;
    -moz-animation: loading 2s ease infinite;
    animation: loading 2s ease infinite;
  }

  @-webkit-keyframes loading {
    0% {
      background-position: 0% 57%;
    }
    50% {
      background-position: 100% 44%;
    }
    100% {
      background-position: 0% 57%;
    }
  }
  @-moz-keyframes loading {
    0% {
      background-position: 0% 57%;
    }
    50% {
      background-position: 100% 44%;
    }
    100% {
      background-position: 0% 57%;
    }
  }
  @keyframes loading {
    0% {
      background-position: 0% 57%;
    }
    50% {
      background-position: 100% 44%;
    }
    100% {
      background-position: 0% 57%;
    }
  }
</style>

<main>
  <div class="container">
    <div class="title">Ligo Tickets Demo</div>
    <div class="subtitle">This dapp showcases how tickets work on Tezos</div>
    <div class="subtitle">
      Read more about it in <a
        href="https://medium.com/ecad-labs-inc/how-to-use-tickets-with-ligo-e773422644b7"
        target="_blank"
        rel="noopener noreferrer nofollow">this article</a
      >
    </div>
    <br />
    <div>
      {#if userAddress}
        {#if loadingProfile}
          <div class="tickets">Loading your details...</div>
        {:else}
          <div class="tickets">
            {#if userTickets && userTicketValidity}
              <div>Number of tickets: {userTickets.amount}</div>
              <div>Ticket type: {userTickets.value}</div>
              <div>Ticketer: {ticketerAddress}</div>
              <div>
                Valid until: {new Date(
                  +new Date(userTicketValidity).getTime() +
                    +ticketerStorage.data.ticket_validity * 1000
                ).toISOString()}
              </div>
            {:else}
              You don't have any tickets yet.
            {/if}
          </div>
          <br />
          <div class="buttons">
            <button
              class:loading={loadingBuy}
              disabled={loadingBuy}
              on:click={async () => {
                if (!loadingBuy) {
                  await buyTickets(1);
                }
              }}
            >
              Buy 1 standard ticket
            </button>
            {#if userTickets && userTickets.amount > 0}
              <button class:loading={loadingRedeem} on:click={redeemTicket}>
                Redeem 1 standard ticket
              </button>
            {/if}
            <button on:click={disconnect}>Disconnect</button>
          </div>
        {/if}
      {:else}
        <button on:click={connect}>Connect now!</button>
      {/if}
    </div>
  </div>
</main>
