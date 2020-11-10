defmodule ExBanking.UserProducer do
  use GenStage

  def init(counter) do
    {:producer, {:queue.new(), counter}}
  end

  def start_link(user) do
    GenStage.start_link(__MODULE__, 0, name: registry_tuple(user))
  end

  def make_operation(%{type: :deposit, to_user: user} = operation) do
    GenStage.call(registry_tuple(user), operation)
  end

  def make_operation(%{from_user: user} = operation) do
    GenStage.call(registry_tuple(user), operation)
  end

  def handle_call(operation, from, {queue, pending_demand})
      when pending_demand > 0 do
    queue = :queue.in({from, operation}, queue)

    send(self(), :new_data)
    {:noreply, [], {queue, pending_demand - 1}}
  end

  def handle_call(%{type: :send}, _from, {queue, pending_demand}) do
    error = {:error, :too_many_requests_to_sender}

    {:reply, error, [], {queue, pending_demand}}
  end

  def handle_call(%{receiver: true}, _from, {queue, pending_demand}) do
    error = {:error, :too_many_requests_to_receiver}

    {:reply, error, [], {queue, pending_demand}}
  end

  def handle_call(_operation, _from, {queue, pending_demand}) do
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

  def handle_demand(demand, {queue, pending_demand}) when demand > 0 do
    case :queue.out(queue) do
      {{:value, operation}, queue} ->
        {:noreply, [operation], {queue, demand + pending_demand - 1}}

      {:empty, queue} ->
        {:noreply, [], {queue, demand + pending_demand}}
    end
  end

  defp registry_tuple(user) do
    {:via, Registry, {Registry.User, user}}
  end
end
