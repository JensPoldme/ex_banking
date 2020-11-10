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

  def handle_info(:get_user, user) do
    :ets.match(__MODULE__, {{user, :"$1"}, :"$2"})
  end

  def handle_info(:deposit, operation) do
    :ets.lookup(__MODULE__, {operation.to_user, operation.currency})
    |> deposit(operation)
  end

  def handle_info(:withdraw, operation) do
    :ets.lookup(__MODULE__, {operation.from_user, operation.currency})
    |> withdraw(operation.amount)
  end

  def handle_info(:get_balance, operation) do
    :ets.lookup(__MODULE__, {operation.from_user, operation.currency})
    |> get_balance()
  end

  def handle_info(:send, operation) do
    :ets.lookup(__MODULE__, {operation.from_user, operation.currency})
    |> send_amount(operation)
  end

  defp deposit([], operation) do
    :ets.insert(__MODULE__, {{operation.to_user, operation.currency}, operation.amount})
    [{_, new_balance}] = :ets.lookup(__MODULE__, {operation.to_user, operation.currency})

    {:ok, new_balance}
  end

  defp deposit([{{user, currency}, balance}], operation) do
    :ets.insert(__MODULE__, {{user, operation.currency}, operation.amount + balance})
    [{_, new_balance}] = :ets.lookup(__MODULE__, {user, currency})

    {:ok, new_balance}
  end

  defp withdraw([], _amount) do
    {:error, :not_enough_money}
  end

  defp withdraw([{_key, balance}], amount) when amount > balance, do: {:error, :not_enough_money}

  defp withdraw([{{user, currency}, balance}], amount) do
    new_balance = balance - amount

    :ets.select_replace(__MODULE__, [
      {{user, :"$1", :"$2"}, [{:==, :"$1", currency}], [{{user, :"$1", {:-, :"$2", amount}}}]}
    ])

    {:ok, new_balance}
  end

  defp get_balance([]), do: {:ok, 0}

  defp get_balance([{_key, balance}]), do: {:ok, balance}

  def send_amount([], _amount), do: {:error, :not_enough_money}

  def send_amount([{_key, balance}], %{amount: amount}) when amount > balance,
    do: {:error, :not_enough_money}

  def send_amount([{key, balance}], operation) do
    new_balance = balance - operation.amount
    :ets.insert(__MODULE__, {key, new_balance})

    new_operation = %{
      type: :deposit,
      to_user: operation.to_user,
      from_user: operation.from_user,
      amount: operation.amount,
      currency: operation.currency,
      receiver: true
    }

    {:ok, receiver_balance} = ExBanking.UserProducer.make_operation(new_operation)

    {:ok, new_balance, receiver_balance}
  end
end
