defmodule ExBanking.CacheWorker do
  use GenServer

  def start do
    GenServer.start(__MODULE__, :ok, name: __MODULE__)
  end

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(args) do
    {:ok, args}
  end

  def restart do
    process = Process.whereis(__MODULE__)
    Process.exit(process, :normal)
    start()
  end

  def table do
    GenServer.call(__MODULE__, :retrieve_table)
  end

  def handle_call(:retrieve_table, _from, table) do
    {:reply, table, table}
  end

  def handle_info({:"ETS-TRANSFER", table, _pid, _data}, _state) do
    {:noreply, table}
  end

  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [] ->
        nil

      value ->
        value
    end
  end

  def put(data), do: :ets.insert(__MODULE__, data)

  def member(key), do: :ets.member(__MODULE__, key)

  def select(pattern), do: :ets.select(__MODULE__, [pattern])

  def replace(pattern), do: :ets.select_replace(__MODULE__, [pattern])

  # NEW implementation
  def handle_info(:get_user, state) do
    :ets.match(__MODULE__, {{state.user, :"$1"}, :"$2"})
  end

  def handle_info(:deposit, state) do
    new_balance = :ets.replace(__MODULE__, {{state.user, :"$1", :"$2"}, [{:==, :"$1", state.currency}],
    [{{state.user, :"$1", {:+, :"$2", state.amount}}}]})

    {:ok, new_balance}
  end

  def handle_info(:withdraw, state) do
    :ets.lookup(__MODULE__, {state.user, state.currency})
    |> withdraw(state.amount)
  end

  def handle_info(:get_balance, state) do
    :ets.lookup(__MODULE__, {state.user, state.currency})
    |> get_balance()
  end

  def handle_info(:send, state) do
    :ets.lookup(__MODULE__, {state.user, state.currency})
    |> send(state.amount)
  end

  defp withdraw([], amount), do: {:error, :not_enough_money}

  defp withdraw([{key, balance}], amount) when amount > balance, do: {:error, :not_enough_money}

  defp withdraw([{{user, currency}, balance}], amount) do
    new_balance = balance - amount
    :ets.select_replace(__MODULE__, [{{user, :"$1", :"$2"}, [{:==, :"$1", currency}],
    [{{user, :"$1", {:-, :"$2", amount}}}]}])

    {:ok, new_balance}
  end

  defp get_balance([]), do: {:ok, 0}

  defp get_balance([{key, balance}]), do: {:ok, balance}

  defp send([], _), do: {:error, :not_enough_money}

  defp send([{key, balance}], amount) when amount > balance,
    do: {:error, :not_enough_money}

  defp send([{key, balance}], amount) do
    new_balance = balance - amount
    :ets.insert(__MODULE__, {key, new_balance})
    # {:ok, receiver_balance} = ExBanking.UserProducer.make_transaction(%{transaction | type: :deposit})

    # {:ok, new_balance, receiver_balance}
  end
end
