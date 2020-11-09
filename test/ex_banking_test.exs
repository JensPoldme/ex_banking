defmodule ExBankingTest do
  use ExUnit.Case
  doctest ExBanking

  alias ExBanking.CacheWorker, as: Cache

  setup do
    Cache.restart()
    user = "user"
    currency = "euro"
    balance = 10

    receiver = "to_user"

    Cache.put([{user, currency, balance}, {receiver, currency, balance}])

    {:ok, %{receiver: receiver, user: user, currency: currency, balance: balance}}
  end

  describe "create_user/1" do
    test "success" do
      assert ExBanking.create_user("new user") == :ok
    end

    test "error - user already exists", %{user: user} do
      assert ExBanking.create_user(user) == {:error, :user_already_exists}
    end

    test "error - wrong arguments" do
      assert ExBanking.create_user(190) == {:error, :wrong_arguments}
    end
  end

  describe "deposit/3" do
    test "success - deposit with new currency", %{user: user} do
      assert {:ok, 10} == ExBanking.deposit(user, 10, "dollar")
    end

    test "success - deposit with existing currency", %{user: user, currency: currency} do
      assert {:ok, 20} == ExBanking.deposit(user, 10, currency)
    end

    test "wrong arguments", %{user: user, currency: currency} do
      assert ExBanking.deposit(:user, 10, currency) == {:error, :wrong_arguments}
      assert ExBanking.deposit(user, "10", currency) == {:error, :wrong_arguments}
      assert ExBanking.deposit(user, 10, :currency) == {:error, :wrong_arguments}
    end

    test "user does not exist" do
      assert ExBanking.deposit("unknown user", 10, "euro") == {:error, :user_does_not_exist}
    end

    test "error - amount is negative", %{user: user, currency: currency} do
      assert ExBanking.deposit(user, -10, currency) == {:error, :wrong_arguments}
    end
  end

  describe "withdraw/3" do
    test "success - withdraw amount", %{user: user, currency: currency} do
      assert {:ok, 5} == ExBanking.withdraw(user, 5, currency)
    end

    test "error - not enough money", %{user: user, currency: currency, balance: balance} do
      assert ExBanking.withdraw(user, balance + 1, currency) == {:error, :not_enough_money}
    end

    test "error - wrong arguments", %{user: user, currency: currency} do
      assert ExBanking.deposit(:user, 10, currency) == {:error, :wrong_arguments}
      assert ExBanking.deposit(user, "10", currency) == {:error, :wrong_arguments}
      assert ExBanking.deposit(user, 10, :currency) == {:error, :wrong_arguments}
    end

    test "error - user does not exist" do
      assert ExBanking.deposit("unknown user", 10, "euro") == {:error, :user_does_not_exist}
    end

    test "error - currency does not exist for the user", %{user: user} do
      assert ExBanking.withdraw(user, 10, "yen") == {:error, :wrong_arguments}
    end

    test "error - amount is negative", %{user: user, currency: currency} do
      assert ExBanking.withdraw(user, -10, currency) == {:error, :wrong_arguments}
    end
  end

  describe "get_balance/2" do
    test "success", %{user: user, currency: currency} do
      assert ExBanking.get_balance(user, currency) == {:ok, 10}
    end

    test "error - wrong arguments", %{user: user, currency: currency} do
      assert ExBanking.get_balance(:user, currency) == {:error, :wrong_arguments}
      assert ExBanking.get_balance(user, :euro) == {:error, :wrong_arguments}
    end

    test "error - currency does not exist", %{user: user} do
      assert ExBanking.get_balance(user, "yen") == {:error, :wrong_arguments}
    end
  end

  describe "send/4" do
    test "success", %{receiver: receiver, user: user, currency: currency, balance: balance} do
      amount = 5
      assert ExBanking.send(user, receiver, amount, currency) == {:ok, 5, 15}
      assert Cache.get(receiver) == [{receiver, currency, balance + amount}]
      assert Cache.get(user) == [{user, currency, balance - amount}]
    end

    test "error - sender does not exist", %{receiver: receiver, currency: currency} do
      assert ExBanking.send("unknown user", receiver, 5, currency) ==
               {:error, :sender_does_not_exist}
    end

    test "error - receiver does not exist", %{user: user, currency: currency, balance: balance} do
      assert ExBanking.send(user, "receiver", 5, currency) == {:error, :receiver_does_not_exist}
      assert Cache.get(user) == [{user, currency, balance}]
    end

    test "error - wrong arguments", %{user: user, receiver: receiver, currency: currency} do
      assert ExBanking.send(:user, receiver, 10, currency) == {:error, :wrong_arguments}
      assert ExBanking.send(user, :receiver, 10, currency) == {:error, :wrong_arguments}
      assert ExBanking.send(user, receiver, "10", currency) == {:error, :wrong_arguments}
      assert ExBanking.send(user, receiver, 10, :euro) == {:error, :wrong_arguments}
    end

    test "error - not enough money", %{user: user, receiver: receiver, currency: currency} do
      assert ExBanking.send(user, receiver, 100, currency) == {:error, :not_enough_money}
    end

    test "error - currency does not exist", %{user: user, receiver: receiver} do
      assert ExBanking.send(user, receiver, 100, "yen") == {:error, :wrong_arguments}
    end

    test "error - amount is negative", %{user: user, receiver: receiver, currency: currency} do
      assert ExBanking.send(user, receiver, -10, currency) == {:error, :wrong_arguments}
    end
  end
end
