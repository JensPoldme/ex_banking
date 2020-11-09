defmodule ExBanking.UserConsumer do
  @moduledoc """
  This consumer puts backpressure into the `ExBanking.User` producer,
  requesting a maximum of 10 items at a time
  After it is started, it subscribes to the producer `:via:` its name.
  """
  use GenStage
  alias ExBanking.Transaction
  alias ExBanking.CacheWorker, as: Cache

  @max_demand 10

  @spec start_link(user :: binary) :: {:ok, pid()}
  def start_link(user) do
    {:ok, consumer} = GenStage.start_link(__MODULE__, user, name: via_tuple(user <> "consumer"))
    GenStage.sync_subscribe(consumer, to: via_tuple(user), max_demand: @max_demand, min_demand: 1)
    {:ok, consumer}
  end

  def init(_) do
    {:consumer, :ok}
  end

  defp via_tuple(user) do
    {:via, Registry, {Registry.User, user}}
  end

  def handle_events(transactions, _from, state) do
    for {origin, transaction} <- transactions do
      result = dispatch_transaction(transaction)
      GenStage.reply(origin, result)
    end

    {:noreply, [], state}
  end

  @doc """
  Makes the required transaction
  """
  def dispatch_transaction(%Transaction{type: :deposit} = transaction) do
    Cache.deposit(transaction)
  end

  def dispatch_transaction(%Transaction{type: :withdraw} = transaction) do
    Cache.withdraw(transaction)
  end

  def dispatch_transaction(%Transaction{type: :balance} = transaction) do
    Cache.get_balance(transaction)
  end

  def dispatch_transaction(%Transaction{type: :send} = transaction) do
    Cache.send_amount(transaction)
  end
end
