defmodule ExBanking.ExBankingServiceTest do
  use ExUnit.Case
  alias ExBanking.CacheWorker, as: Cache
  alias ExBanking.ExBankingService

  setup do
    Cache.restart()
    user = "user"
    currency = "euro"
    balance = 10
    Cache.put({user, currency, balance})

    {:ok, %{user: user, currency: currency, balance: balance}}
  end

  describe "validate_user/1" do
    test "validate one user", %{user: user} do
      assert ExBankingService.validate_user(user)
    end

    test "false" do
      assert ExBankingService.validate_user(["unknown user"]) == {:error, :user_does_not_exist}
    end
  end

  describe "deposit/3" do
    test "deposit with new currency", %{user: user} do
      assert 10 == ExBankingService.deposit(user, 10, "dollar")
    end

    test "deposit to existing currency", %{user: user, currency: currency} do
      assert 20 == ExBankingService.deposit(user, 10, currency)
    end
  end

  describe "withdraw/3" do
    test "success", %{user: user, currency: currency} do
      assert 5 == ExBankingService.withdraw(user, 5, currency)
    end
  end

  describe "get_balance/2" do
    test "success", %{user: user, currency: currency} do
      assert 10 == ExBankingService.get_balance(user, currency)
    end
  end
end
