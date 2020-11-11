defmodule ExBanking.Operation do
  alias ExBanking.UserSupervisor

  @enforce_keys [:type, :from_user, :amount, :currency]
  @fields quote(
            do: [
              type: String.t(),
              from_user: String.t(),
              to_user: String.t() | nil,
              amount: number() | nil,
              currency: String.t()
            ]
          )
  defstruct Keyword.keys(@fields)

  @type t() :: %__MODULE__{unquote_splicing(@fields)}

  def new_operation(type, <<from_user::binary>>, <<currency::binary>>) do
    user_exists?(from_user)
    |> create_operation(type, from_user, nil, nil, currency)
  end

  def new_operation(_type, _from_user, _currency), do: {:error, :wrong_arguments}

  def new_operation(:deposit, <<to_user::binary>>, amount, <<currency::binary>>)
      when is_number(amount) and 0 < amount do
    user_exists?(to_user)
    |> create_operation(:deposit, nil, to_user, amount, currency)
  end

  def new_operation(type, <<from_user::binary>>, amount, <<currency::binary>>)
      when is_number(amount) and 0 < amount do
    user_exists?(from_user)
    |> create_operation(type, from_user, nil, amount, currency)
  end

  def new_operation(_type, _from_user, _amount, _currency), do: {:error, :wrong_arguments}

  def new_operation(
        type,
        <<from_user::binary>>,
        <<to_user::binary>>,
        amount,
        <<currency::binary>>
      )
      when is_number(amount) and 0 < amount do
    with {:sender, true} <- {:sender, user_exists?(from_user)},
         {:receiver, true} <- {:receiver, user_exists?(to_user)} do
      create_operation(type, from_user, to_user, amount, currency)
    else
      {:sender, false} -> {:error, :sender_does_not_exist}
      {:receiver, false} -> {:error, :receiver_does_not_exist}
    end
  end

  def new_operation(_type, _from_user, _to_user, _amount, _currency),
    do: {:error, :wrong_arguments}

  defp create_operation(true, type, from_user, to_user, amount, currency) do
    %__MODULE__{
      type: type,
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    }
  end

  defp create_operation(false, _type, _from_user, _to_user, _amount, _currency),
    do: {:error, :user_does_not_exist}

  defp create_operation(:send, from_user, to_user, amount, currency) do
    %__MODULE__{
      type: :send,
      from_user: from_user,
      to_user: to_user,
      amount: amount,
      currency: currency
    }
  end

  defp user_exists?(user), do: UserSupervisor.user_exists?(user)
end
