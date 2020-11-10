defmodule ExBanking.UserSupervisor do
  use Supervisor

  @name ExBanking.UserSupervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def create_user(user) do
    user_exists?(user)
    |> start_user_processes(user)
    |> respond()
  end

  def user_exists?(user) do
    case Registry.lookup(Registry.User, user) do
      [_ | _] -> true
      _ -> false
    end
  end

  defp start_user_processes(true, _user), do: {:error, :user_already_exists}

  defp start_user_processes(false, user) do
    {:ok, producer} =
      DynamicSupervisor.start_child(
        ExBanking.UserProducer.DynamicSupervisor,
        worker(ExBanking.UserProducer, [user])
      )

    {:ok, _} =
      DynamicSupervisor.start_child(
        ExBanking.UserProducer.DynamicSupervisor,
        worker(ExBanking.UserConsumer, [user])
      )

    {:ok, producer}
  end

  defp respond({:ok, _}), do: :ok
  defp respond(error), do: error

  def init(_) do
    children = [
      {DynamicSupervisor, name: ExBanking.UserProducer.DynamicSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
