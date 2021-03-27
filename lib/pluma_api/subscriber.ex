defmodule PlumaApi.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  @default_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :default_list)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @email_regex ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
  @name_regex ~r/^[\w\s\-']*$/u
  @rid_regex ~r/^[\w_\-']*$/u

  @status_types ["pending", "subscribed", "unsubscribed", "cleaned", "archived"]

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
          PRID: sub.parent_rid
        },
        ip_signup: sub.ip_signup,
      }, opts)

      end

  end

  schema "subscribers" do

    field :mchimp_id, :string, default: ""
    field :email, :string, null: false
    field :list, :string, default: @default_list

    field :rid, :string, default: Nanoid.generate() 
    field :parent_rid, :string, default: ""

    has_many :referees, __MODULE__, foreign_key: :parent_rid, references: :rid
    has_one :referer, __MODULE__, foreign_key: :rid, references: :parent_rid

    # Virtual fields (used for API calls, etc.)

    field :fname, :string, default: ""
    field :lname, :string, default: ""
    field :status, :string, default: "pending"
    field :tags, {:array, :string}, default: []
    field :ip_signup, :string, default: ""
    field :country, :string, default: ""

  end

  def changeset(subscriber, params) do
    fields = 
      [:mchimp_id,
        :email,
        :list,
        :rid,
        :parent_rid,
        :fname,
        :lname,
        :status,
        :tags,
        :ip_signup,
        :country]

    Ecto.Changeset.change(subscriber)
    |> cast(params, fields)
    |> validate_required([:email])
    |> unique_constraint(:email)
    |> validate_format(:email, @email_regex)
    |> validate_format(:fname, @name_regex)
    |> validate_format(:lname, @name_regex)
    |> validate_format(:rid, @rid_regex)
    |> validate_format(:parent_rid, @rid_regex)
    |> validate_inclusion(:status, @status_types)
  end

  def with_id(query \\ __MODULE__, id), do: from s in query, where: ^id == s.id 
  def with_mchimp_id(query \\ __MODULE__, mchimp_id), do: from s in query, where: ^mchimp_id == s.mchimp_id
  def with_parent_rid(query \\ __MODULE__, parent_rid), do: from s in query, where: ^parent_rid == s.parent_rid
  def with_rid(query \\ __MODULE__, rid), do: from s in query, where: ^rid == s.rid 
  def with_email(query \\ __MODULE__, email), do: from s in query, where: ^email == s.email
  def with_list(query \\ __MODULE__, list_id), do: from s in query, where: ^list_id == s.list_id

  def preload_referees(query \\ __MODULE__), do: from s in query, preload: [:referees]
  
end
