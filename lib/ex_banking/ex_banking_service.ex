defmodule ExBanking.ExBankingService do
  alias ExBanking.CacheWorker, as: Cache

  def create_user(user) do
    case validate_user(user) do
      {:error, _} -> Cache.put({user, nil})
      true -> {:error, :user_already_exists}
    end
  end

  def deposit(user, amount, currency) do
    case Cache.replace(
           {{user, :"$1", :"$2"}, [{:==, :"$1", currency}],
            [{{user, :"$1", {:+, :"$2", amount}}}]}
         ) do
      1 -> get_balance(user, currency)
      0 -> deposit_with_new_currency(user, amount, currency)
    end
  end

  def withdraw(user, amount, currency) do
    case Cache.replace(
           {{user, :"$1", :"$2"}, [{:==, :"$1", currency}],
            [{{user, :"$1", {:-, :"$2", amount}}}]}
         ) do
      1 -> get_balance(user, currency)
      0 -> {:error, :wrong_arguments}
    end
  end

  def validate_user(user) do
    case Cache.member(user) do
      true -> true
      false -> {:error, :user_does_not_exist}
    end
  end

  def get_balance(user, currency) do
    case Cache.select({{user, :"$1", :"$2"}, [{:==, :"$1", currency}], [{{:"$2"}}]}) do
      [] -> {:error, :wrong_arguments}
      [{balance}] -> balance
    end
  end

  def check_balance(balance, amount) do
    case balance >= amount do
      true -> true
      false -> {:error, :not_enough_money}
    end
  end

  defp deposit_with_new_currency(user, amount, currency) do
    Cache.put({user, currency, amount})
    get_balance(user, currency)
  end
end
