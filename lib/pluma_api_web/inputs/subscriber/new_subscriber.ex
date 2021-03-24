defmodule PlumaApiWeb.Inputs.Subscriber.NewSubscriber do
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__
  require Jason

  @moduledoc """
  Provides validation for new subscriber calls to the web-based API.

  Defines an implementation of the JSON encoder for seamless encoding
  into an acceptable Mailchimp API data format.
  """

  @email_regex ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
  @name_regex ~r/^[\w\s]*$/
  @rid_regex ~r/^[\w_-]*$/

  # spares us having to define separate functions throughout our controllers
  # to encode our fields back into JSON.
  defimpl Jason.Encoder, for: [__MODULE__] do
    
    def encode(sub, opts) do

      Jason.Encode.map(%{
        email_address: sub.email,
        status: sub.status,
        tags: sub.tags,
        merge_fields: %{
          FNAME: sub.fname,
          LNAME: sub.lname,
          RID: sub.rid,
          PRID: sub.prid
        },
        ip_signup: sub.ip_signup
      }, opts)

      end

  end

  embedded_schema do
    field :fname, :string, default: ""
    field :lname, :string, default: ""
    field :email, :string
    field :status, :string, default: "pending"
    field :tags, {:array, :string}, default: []
    field :rid, :string, default: Nanoid.generate() 
    field :prid, :string, default: ""
    field :ip_signup, :string, default: ""
  end

  def changeset(new_subscriber, params \\ %{}) do
    new_subscriber
    |> cast(params, [:fname, :lname, :email, :rid, :prid, :ip_signup, :tags, :status])
    |> validate_required([:email])
    |> validate_format(:email, @email_regex)
    |> validate_format(:fname, @name_regex)
    |> validate_format(:lname, @name_regex)
    |> validate_format(:rid, @rid_regex)
    |> validate_format(:prid, @rid_regex)
    |> validate_inclusion(:status, ["pending", "subscribed"])
  end

  @doc """
  Returns a `{:ok, %NewSubscriber{}}` tuple or a `{:error, keyword(atom: {String.t, list})}` tuple.
  """
  def validate_input(params) do
    chgst = %NewSubscriber{}
            |> changeset(params)

    if chgst.valid? do
      {:ok, apply_changes(chgst)}
    else
      {:error, {:validation, chgst}}
    end
  end

end
