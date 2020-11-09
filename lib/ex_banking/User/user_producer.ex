defmodule ExBanking.User do
  @moduledoc """
  Genstage producer is called directly from ex_banking
  """
  use GenStage
  alias ExBanking.Transaction

  def init(counter) do
    {:producer, {:queue.new(), counter}}
  end

  ###
  ## Public API
  ###
  def start_link(user) do
    GenStage.start_link(__MODULE__, 0, name: via_tuple(user))
  end

  @doc """
  Sends the transaction to its user
  """
  @spec make_transaction(transaction :: Transaction.t()) :: tuple()
  def make_transaction(%Transaction{type: :send, sender: user} = transaction) do
    GenStage.call(via_tuple(user), {:transaction, transaction})
  end

  def make_transaction(%Transaction{receiver: user} = transaction) do
    GenStage.call(via_tuple(user), {:transaction, transaction})
  end

  defp via_tuple(user) do
    {:via, Registry, {Registry.User, user}}
  end

  ###
  ## GenStage calls
  ###

  def handle_call({:transaction, transaction}, from, {queue, pending_demand})
      when pending_demand > 0 do
    queue = :queue.in({from, transaction}, queue)

    send(self(), :new_data)
    {:noreply, [], {queue, pending_demand - 1}}
  end

  def handle_call({:transaction, _transaction}, _from, {queue, pending_demand}) do
    error = {:error, :too_many_requests_to_user}

    {:reply, error, [], {queue, pending_demand}}
  end

  def handle_info(:new_data, {queue, pending_demand}) do
    case :queue.out(queue) do
      {{:value, transaction}, queue} ->
        {:noreply, [transaction], {queue, pending_demand}}

      {:empty, queue} ->
        {:noreply, [], {queue, pending_demand}}
    end
  end

  def handle_demand(incoming_demand, {queue, pending_demand}) when incoming_demand > 0 do
    case :queue.out(queue) do
      {{:value, transaction}, queue} ->
        {:noreply, [transaction], {queue, incoming_demand + pending_demand - 1}}

      {:empty, queue} ->
        {:noreply, [], {queue, incoming_demand + pending_demand}}
    end
  end
end
