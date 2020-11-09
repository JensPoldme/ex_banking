defmodule ExBanking.CacheSupervisor do
  use GenServer

  @spec start_link(atom, list) :: {:ok, pid}
  def start_link(target_process_name, ets_options \\ []) do
    {:ok, pid} = GenServer.start_link(__MODULE__, :ok)
    GenServer.call(pid, {:create_table, target_process_name, ets_options})
    {:ok, pid}
  end

  def init(args) do
    {:ok, args}
  end

  @spec table(pid) :: integer
  def table(manager) do
    GenServer.call(manager, :retrieve_table)
  end

  def handle_call({:create_table, target_process_name, ets_options}, _from, _state) do
    ets_options = ets_options ++ [{:heir, self(), {}}]
    table = :ets.new(target_process_name, ets_options)

    give_away(table, target_process_name)

    {:reply, table, {table, target_process_name}}
  end

  def handle_call(:retrieve_table, _from, {table, _} = state) do
    {:reply, table, state}
  end

  def handle_info({:"ETS-TRANSFER", table, _pid, _data}, {_, target_process_name} = state) do
    give_away(table, target_process_name)
    {:noreply, state}
  end

  defp give_away(table, target_process_name) do
    pid = wait_for(target_process_name)
    :ets.give_away(table, pid, {})
  end

  defp wait_for(module) do
    pid = Process.whereis(module)

    if pid && Process.alive?(pid) do
      pid
    else
      wait_for(module)
    end
  end
end
