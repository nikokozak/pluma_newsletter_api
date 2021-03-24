defmodule PlumaApiWeb.Inputs.Subscriber.GetSubscriber do
  use Ecto.Schema
  import Ecto.Changeset

  @email_regex ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
  @rid_regex ~r/^[\w_-]*$/

  embedded_schema do
    field :email, :string
    field :rid, :string
  end

  def changeset(get_subscriber, params) do
    get_subscriber
    |> cast(params, [:email, :rid])
    |> validate_required_inclusion([:email, :rid])
    |> validate_format(:email, @email_regex)
    |> validate_format(:rid, @rid_regex)
  end

  defp validate_required_inclusion(changeset, fields, _opts \\ []) do
    if Enum.any?(fields, fn(field) -> get_field(changeset, field) end),
      do: changeset,
    else: add_error(changeset, hd(fields), "One of the fields must be present: #{inspect fields}")
  end

  def validate_input(input) do
    chgst = __MODULE__.changeset(%__MODULE__{}, input)

    if chgst.valid?,
      do: {:ok, apply_changes(chgst)},
    else: {:error, {:validation, chgst}}
  end
end
