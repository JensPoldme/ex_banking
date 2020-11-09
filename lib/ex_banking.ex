defmodule ExBanking do
  alias ExBanking.ExBankingService

  @type banking_error ::
          {:error,
           :wrong_arguments
           | :user_already_exists
           | :user_does_not_exist
           | :not_enough_money
           | :sender_does_not_exist
           | :receiver_does_not_exist
           | :too_many_requests_to_user
           | :too_many_requests_to_sender
           | :too_many_requests_to_receiver}

  def create_user(<<user::binary>>) do
    with true <- ExBankingService.create_user(user) do
      :ok
    else
      error -> error
    end
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  def deposit(<<user::binary>>, amount, <<currency::binary>>)
      when is_number(amount) and 0 < amount do
    with true <- ExBankingService.validate_user(user),
         new_balance <- ExBankingService.deposit(user, amount, currency) do
      {:ok, new_balance}
    else
      error -> error
    end
  end

  def deposit(_user, _amount, _currency), do: {:error, :wrong_arguments}

  def withdraw(<<user::binary>>, amount, <<currency::binary>>)
      when is_number(amount) and 0 < amount do
    with true <- ExBankingService.validate_user(user),
         balance when is_number(balance) <- ExBankingService.get_balance(user, currency),
         true <- ExBankingService.check_balance(balance, amount),
         new_balance <- ExBankingService.withdraw(user, amount, currency) do
      {:ok, new_balance}
    else
      error -> error
    end
  end

  def withdraw(_user, _amount, _currency), do: {:error, :wrong_arguments}

  @spec get_balance(any, any) :: {:error, :user_does_not_exist | :wrong_arguments} | {:ok, any}
  def get_balance(<<user::binary>>, <<currency::binary>>) do
    with true <- ExBankingService.validate_user(user),
         balance when is_number(balance) <- ExBankingService.get_balance(user, currency) do
      {:ok, balance}
    else
      error -> error
    end
  end

  def get_balance(_user, _currency), do: {:error, :wrong_arguments}

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(<<from_user::binary>>, <<to_user::binary>>, amount, <<currency::binary>>)
      when is_number(amount) and 0 < amount do
    with {:sender, true} <- {:sender, ExBankingService.validate_user(from_user)},
         {:receiver, true} <- {:receiver, ExBankingService.validate_user(to_user)},
         sender_current_balance when is_number(sender_current_balance) <-
           ExBankingService.get_balance(from_user, currency),
         true <- ExBankingService.check_balance(sender_current_balance, amount),
         sender_new_balance <- ExBankingService.withdraw(from_user, amount, currency),
         receiver_balance <- ExBankingService.deposit(to_user, amount, currency) do
      {:ok, sender_new_balance, receiver_balance}
    else
      {:sender, {_error, :user_does_not_exist}} -> {:error, :sender_does_not_exist}
      {:receiver, {_error, :user_does_not_exist}} -> {:error, :receiver_does_not_exist}
      error -> error
    end
  end

  def send(_from_user, _to_user, _amount, _currency), do: {:error, :wrong_arguments}
end
