defmodule PerformanceTest do
  use ExUnit.Case, async: false

  import ExBanking

  test "too many deposits" do
    create_user("user")

    result_list =
    Enum.map(1..15, fn _ -> Task.async(fn -> deposit("user", 100, "dollar") end) end)
    |> Enum.map(&Task.await/1)

    IO.inspect(result_list)
  end

  @tag :skip
  test "too many withdraws" do
    create_user("user2")
    deposit("user2", 10000, "dollar")

    result_list =
    Enum.map(1..15, fn _ -> Task.async(fn -> withdraw("user2", 100, "dollar") end) end)
    |> Enum.map(&Task.await/1)

    assert Enum.member?(result_list, {:error, :too_many_requests_to_user}) == true
  end

  @tag :skip
  test "too many request to sender" do
    create_user("user3")
    deposit("user3", 10000, "dollar")

    create_user("user4")
    create_user("user5")

    result_list =
    Enum.map(1..15, fn i -> Task.async(fn ->
      case i > 7 do
        true -> send("user3", "user4", 100, "dollar")
        false -> send("user3", "user5", 100, "dollar")
      end
    end) end)
    |> Enum.map(&Task.await/1)

    assert Enum.member?(result_list, {:error, :too_many_requests_to_sender}) == true
  end

  @tag :skip
  test "too many request to receiver" do
    create_user("user7")
    create_user("user8")
    create_user("user9")
    deposit("user7", 10000, "dollar")
    deposit("user8", 10000, "dollar")
    deposit("user9", 10000, "dollar")

    create_user("user6")

    result_list =
    Enum.map(1..19, fn i -> Task.async(fn ->
      cond do
        i < 7 -> send("user7", "user6", 100, "dollar")
        i < 14 -> send("user8", "user6", 100, "dollar")
        i < 20 -> send("user9", "user6", 100, "dollar")
      end
    end) end)
    |> Enum.map(&Task.await/1)

    assert Enum.member?(result_list, {:error, :too_many_requests_to_receiver}) == true
  end

  @tag :skip
  test "too many request to receiver, sender balance not affected when receiver doesn't receive" do
    create_user("user10")
    create_user("user11")
    deposit("user10", 800, "dollar")
    deposit("user11", 800, "dollar")

    create_user("user12")

    result_list =
    Enum.map(1..15, fn i -> Task.async(fn ->
      cond do
        i < 8 -> send("user11", "user12", 100, "dollar")
        i < 16 -> send("user10", "user12", 100, "dollar")
      end
    end) end)
    |> Enum.map(&Task.await/1)


    assert Enum.member?(result_list, {:error, :too_many_requests_to_receiver}) == true

    :timer.sleep(500)

    #The sum of the three balances must be equal to the total deposited in
    #user10 and user11 balances, regardless of having receiver errors
    {:ok, balance_10} = get_balance("user10", "dollar")
    {:ok, balance_11} = get_balance("user11", "dollar")
    {:ok, balance_12} = get_balance("user12", "dollar")

    assert balance_10 + balance_11 + balance_12 == 1600
  end
end
