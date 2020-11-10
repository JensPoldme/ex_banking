defmodule ExBanking do
  alias ExBanking.{UserProducer, Operation}

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

  @spec create_user(user :: String.t) :: :ok | banking_error
  def create_user(<<user::binary>>) do
    ExBanking.UserSupervisor.create_user(user)
  end

  def create_user(_user), do: {:error, :wrong_arguments}

  @spec deposit(user :: String.t(), amount :: number, currency :: String.t()) ::
          {:ok, new_balance :: number} | banking_error
  def deposit(user, amount, currency) do
    with operation = %{} <- Operation.new_operation(:deposit, user, amount, currency),
         {:ok, balance} <- UserProducer.make_operation(operation) do
      {:ok, convert(balance)}
    else
      error -> error
    end
  end

  @spec withdraw(user :: String.t, amount :: number, currency :: String.t) :: {:ok, new_balance :: number} | banking_error
  def withdraw(user, amount, currency) do
    with operation = %{} <- Operation.new_operation(:withdraw, user, amount, currency),
         {:ok, balance} <- UserProducer.make_operation(operation) do
      {:ok, convert(balance)}
    else
      error -> error
    end
  end

  @spec get_balance(any, any) :: {:error, :user_does_not_exist | :wrong_arguments} | {:ok, any}
  def get_balance(user, currency) do
    with operation = %{} <- Operation.new_operation(:get_balance, user, currency),
         {:ok, balance} <- UserProducer.make_operation(operation) do
      {:ok, convert(balance)}
    else
      error -> error
    end
  end

  @spec send(
          from_user :: String.t(),
          to_user :: String.t(),
          amount :: number,
          currency :: String.t()
        ) :: {:ok, from_user_balance :: number, to_user_balance :: number} | banking_error
  def send(from_user, to_user, amount, currency) do
    with operation = %{} <- Operation.new_operation(:send, from_user, to_user, amount, currency),
         {:ok, sender_balance, receiver_balance} <- UserProducer.make_operation(operation) do
      {:ok, convert(sender_balance), convert(receiver_balance)}
    else
      error -> error
    end
  end

  defp convert(amount) do
    amount
    |> Decimal.new()
    |> Decimal.round(2)
    |> Decimal.to_float()
  end
end
