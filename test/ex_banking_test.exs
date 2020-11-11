defmodule ExBankingTest do
  use ExUnit.Case, async: false
  doctest ExBanking

  @range 10000

  describe "create_user/1" do
    test "success" do
      user = "user#{:rand.uniform(@range)}"
      assert ExBanking.create_user(user) == :ok
    end

    test "error - user already exists" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      assert ExBanking.create_user(user) == {:error, :user_already_exists}
    end

    test "error - wrong arguments" do
      assert ExBanking.create_user(190) == {:error, :wrong_arguments}
    end
  end

  describe "deposit/3" do
    test "success - deposit with new currency" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      assert ExBanking.deposit(user, 10, "yen") == {:ok, 10.00}
    end

    test "success - deposit with existing currency" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert {:ok, 20} == ExBanking.deposit(user, 10, "euro")
    end

    test "wrong arguments" do
      assert ExBanking.deposit(:user, 10, "euro") == {:error, :wrong_arguments}
      assert ExBanking.deposit("user", 10, :currency) == {:error, :wrong_arguments}
      assert ExBanking.deposit("user", "10", "euro") == {:error, :wrong_arguments}
    end

    test "user does not exist" do
      assert ExBanking.deposit("unknown user", 10, "euro") == {:error, :user_does_not_exist}
    end

    test "error - amount is negative" do
      assert ExBanking.deposit("user", -10, "euro") == {:error, :wrong_arguments}
    end
  end

  describe "withdraw/3" do
    test "success - withdraw amount" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert {:ok, 5.00} == ExBanking.withdraw(user, 5, "euro")
    end

    test "error - not enough money" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert ExBanking.withdraw(user, 11, "euro") == {:error, :not_enough_money}
    end

    test "error - wrong arguments" do
      assert ExBanking.deposit(:user, 10, "euro") == {:error, :wrong_arguments}
      assert ExBanking.deposit("user", "10", "euro") == {:error, :wrong_arguments}
      assert ExBanking.deposit("user", 10, :currency) == {:error, :wrong_arguments}
    end

    test "error - user does not exist" do
      assert ExBanking.deposit("unknown user", 10, "euro") == {:error, :user_does_not_exist}
    end

    test "error - currency does not exist for the user" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert ExBanking.withdraw(user, 10, "yen") == {:error, :not_enough_money}
    end

    test "error - amount is negative" do
      assert ExBanking.withdraw("user", -10, "euro") == {:error, :wrong_arguments}
    end
  end

  describe "get_balance/2" do
    test "success" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert ExBanking.get_balance(user, "euro") == {:ok, 10.00}
    end

    test "error - wrong arguments" do
      assert ExBanking.get_balance(:user, "currency") == {:error, :wrong_arguments}
      assert ExBanking.get_balance("user", :euro) == {:error, :wrong_arguments}
    end

    test "error - currency does not exist" do
      user = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(user)
      ExBanking.deposit(user, 10, "euro")
      assert ExBanking.get_balance(user, "yen") == {:ok, 0.00}
    end
  end

  describe "send/4" do
    test "success" do
      sender = "user#{:rand.uniform(@range)}"
      receiver = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(sender)
      ExBanking.create_user(receiver)
      ExBanking.deposit(sender, 20, "euro")
      assert ExBanking.send(sender, receiver, 5, "euro") == {:ok, 15.00, 5.00}
      assert ExBanking.get_balance(sender, "euro") == {:ok, 15.00}
      assert ExBanking.get_balance(receiver, "euro") == {:ok, 5.00}
    end

    test "error - sender does not exist" do
      assert ExBanking.send("unknown user", "receiver", 5, "currency") ==
               {:error, :sender_does_not_exist}
    end

    test "error - receiver does not exist" do
      sender = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(sender)

      assert ExBanking.send(sender, "receiver", 5, "currency") ==
               {:error, :receiver_does_not_exist}
    end

    test "error - wrong arguments" do
      assert ExBanking.send(:user, "receiver", 10, "currency") == {:error, :wrong_arguments}
      assert ExBanking.send("user", :receiver, 10, "currency") == {:error, :wrong_arguments}
      assert ExBanking.send("user", "receiver", "10", "currency") == {:error, :wrong_arguments}
      assert ExBanking.send("user", "receiver", 10, :euro) == {:error, :wrong_arguments}
    end

    test "error - not enough money" do
      sender = "user#{:rand.uniform(@range)}"
      receiver = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(sender)
      ExBanking.create_user(receiver)
      ExBanking.deposit(sender, 0, "euro")
      assert ExBanking.send(sender, receiver, 100, "euro") == {:error, :not_enough_money}
    end

    test "error - currency does not exist" do
      sender = "user#{:rand.uniform(@range)}"
      receiver = "user#{:rand.uniform(@range)}"
      ExBanking.create_user(sender)
      ExBanking.create_user(receiver)
      assert ExBanking.send(sender, receiver, 100, "yen") == {:error, :not_enough_money}
    end

    test "error - amount is negative" do
      assert ExBanking.send("user", "receiver", -10, "currency") == {:error, :wrong_arguments}
    end
  end
end
