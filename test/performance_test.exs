defmodule PerformanceTest do
  use ExUnit.Case, async: false

  import ExBanking
  alias ExBanking.UserProducer

  test "handles 10 requests" do
    user = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(user)

    result =
      Enum.map(1..10, fn _ -> Task.async(fn -> ExBanking.deposit(user, 10, "dollar") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(fn {res, _} -> res == :ok end)

    assert(result == 10)
  end

  test "too many requests to user" do
    user = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(user)

    result =
      Enum.map(1..11, fn _ -> Task.async(fn -> ExBanking.deposit(user, 10, "dollar") end) end)
      |> Enum.map(&Task.await/1)

    assert Enum.member?(result, {:error, :too_many_requests_to_user}) == true
  end

  test "handles 10 requests per two users concurrently" do
    user = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(user)
    another_user = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(another_user)

    list =
      [user, another_user]
      |> List.duplicate(10)
      |> List.flatten()

    result =
      Enum.map(list, fn u -> Task.async(fn -> ExBanking.deposit(u, 10, "dollar") end) end)
      |> Enum.map(&Task.await/1)
      |> Enum.count(fn {res, _} -> res == :ok end)

    assert(result == 20)
  end

  test "too many request to sender" do
    sender = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(sender)
    ExBanking.deposit(sender, 1000, "dollar")
    receiver_1 = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(receiver_1)
    receiver_2 = "user#{:rand.uniform(1000)}"
    ExBanking.create_user(receiver_2)

    result_list =
      Enum.map(1..11, fn i ->
        Task.async(fn ->
          case i > 5 do
            true -> ExBanking.send(sender, receiver_1, 10, "dollar")
            false -> ExBanking.send(sender, receiver_2, 10, "dollar")
          end
        end)
      end)
      |> Enum.map(&Task.await/1)

    assert Enum.member?(result_list, {:error, :too_many_requests_to_sender}) == true
  end
end
