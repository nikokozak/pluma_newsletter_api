defmodule PlumaApi.Subscriber do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias __MODULE__

  @default_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :default_list)

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "subscribers" do

    field :mchimp_id, :string
    field :email, :string, null: false
    field :list, :string

    field :rid, :string
    field :parent_rid, :string

    has_many :referees, __MODULE__, foreign_key: :parent_rid, references: :rid
    has_one :referer, __MODULE__, foreign_key: :rid, references: :parent_rid

  end

  def insert_changeset(subscriber, params) do
    allowed_params = [:mchimp_id, :email, :list, :rid, :parent_rid]

    Ecto.Changeset.change(subscriber)
    |> changeset_with_allowed_params(allowed_params, params)
  end

  defp changeset_with_allowed_params(subscriber, allowed_params, params \\ %{}) do
    subscriber
    |> cast(params, allowed_params)
    |> validate_required([:email])
  end

  def with_id(query \\ __MODULE__, id), do: from s in query, where: ^id == s.id 
  def with_mchimp_id(query \\ __MODULE__, mchimp_id), do: from s in query, where: ^mchimp_id == s.mchimp_id
  def with_parent_rid(query \\ __MODULE__, parent_rid), do: from s in query, where: ^parent_rid == s.parent_rid
  def with_rid(query \\ __MODULE__, rid), do: from s in query, where: ^rid == s.rid 
  def with_email(query \\ __MODULE__, email), do: from s in query, where: ^email == s.email
  def with_list(query \\ __MODULE__, list_id), do: from s in query, where: ^list_id == s.list_id

  def preload_referees(query \\ __MODULE__), do: from s in query, preload: [:referees]
  
end
