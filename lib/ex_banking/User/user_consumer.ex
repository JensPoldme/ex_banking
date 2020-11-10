defmodule ExBanking.UserConsumer do
  use GenStage
  alias ExBanking.CacheWorker, as: Cache

  @spec start_link(user :: binary) :: {:ok, pid()}
  def start_link(user) do
    {:ok, consumer} =
      GenStage.start_link(__MODULE__, user, name: registry_tuple(user <> "consumer"))

    GenStage.sync_subscribe(consumer, to: registry_tuple(user), max_demand: 10, min_demand: 1)
    {:ok, consumer}
  end

  def init(_) do
    {:consumer, :ok}
  end

  defp registry_tuple(user) do
    {:via, Registry, {Registry.User, user}}
  end

  def handle_events(operations, _from, operation) do
    for {origin, operation} <- operations do
      result = dispatch_transaction(operation)
      GenStage.reply(origin, result)
    end

    {:noreply, [], operation}
  end

  defp dispatch_transaction(operation) do
    Cache.handle_info(operation.type, operation)
  end
end
