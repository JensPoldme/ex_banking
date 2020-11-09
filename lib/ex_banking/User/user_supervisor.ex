defmodule ExBanking.UserSupervisor do
  use Supervisor
  require Logger

  @name ExBanking.UserSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def create_user(name) do
    begin_start(name)
    |> do_start(name)
    |> end_start()
  end

  def begin_start(name) do
    exists?(name)
    |> can_start?
  end

  def exists?(name) do
    Registry.lookup(Registry.User, name)
  end

  def can_start?(list) when length(list) == 0, do: true
  def can_start?(_), do: false

  def do_start(false, _), do: {:error, :user_does_not_exists}

  def do_start(true, name) do
    {:ok, producer} =
      DynamicSupervisor.start_child(
        ExBanking.User.DynamicSupervisor,
        worker(ExBanking.User, [name])
      )

    {:ok, _} =
      DynamicSupervisor.start_child(
        ExBanking.User.DynamicSupervisor,
        worker(ExBanking.UserConsumer, [name])
      )

    {:ok, producer}
  end

  def end_start({:ok, _}), do: :ok
  def end_start({:error, _}), do: {:error, :user_already_exists}
  def end_start(reason), do: reason

  def init(_) do
    children = [
      {DynamicSupervisor, name: ExBanking.User.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
