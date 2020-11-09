defmodule PlumaApi.MailchimpRepo do
  alias PlumaApi.Subscriber
  @api_key Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_key)
  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @api_server Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_server)
  @mailosaur_server Keyword.get(Application.get_env(:pluma_api, :mailchimp), :mailosaur_server)
  @base_url "https://" <> @api_server <> ".api.mailchimp.com/3.0/"

  @hackney_auth [basic_auth: {"plumachile", @api_key}]

  def add_to_audience(subscriber = %Subscriber{}, list_id, test \\ false) do
    HTTPoison.post(
      @base_url <> "lists/" <> list_id <> "/members",
      encode(subscriber, test),
      [],
      [hackney: @hackney_auth]
    )
  end

  def tag_subscriber(email, list_id, tags) when is_list(tags) do
    HTTPoison.post(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email) <> "/tags",
      Jason.encode(%{ tags: tags, is_syncing: false }) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
  end

  def update_merge_field(email, list_id, merge_fields) when is_map(merge_fields) do
    HTTPoison.patch(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      Jason.encode(%{merge_fields: merge_fields}) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
  end

  def check_exists(email, list_id) do
    {:ok, result} = 
      HTTPoison.get(
        @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
        [],
        [hackney: @hackney_auth]
      )

    case result do
      %HTTPoison.Response{status_code: 200} -> true
      _other -> false
    end
  end

  def archive_subscriber(email, list_id) do
    {:ok, result} =
      HTTPoison.delete(
        @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
        [],
        [hackney: @hackney_auth]
      )

    case result do
      %HTTPoison.Response{status_code: 204} -> {:ok, email}
      error -> {:error, error}
    end
  end

  def get_subscriber(email, list_id) do
    {:ok, result} =
      HTTPoison.get(
        @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
        [],
        [hackney: @hackney_auth]
      )

    case result do
      %HTTPoison.Response{status_code: 200, body: body} ->
        {:ok, body}
      error ->
        {:error, error}
    end
  end

  def normalize_database(skip_this_many_emails \\ 0) do
    call = HTTPoison.get(
      @base_url <> "lists/" <> @list_id <> "/members?" <> "count=1000" <> "&offset=#{skip_this_many_emails}" <> "&status=subscribed",
      [],
      [hackney: @hackney_auth]
    )

    case call do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body} = Jason.decode(body)
        members = body["members"]
        {num, _all} = PlumaApi.Repo.delete_all(Subscriber)
        IO.inspect("Deleted #{num} entries")
        add_members_to_db(members)
      other ->
        {:error, other}
    end
  end

  def add_members_to_db(members) when is_list(members) do
    add_member_to_db(members)
  end

  def add_member_to_db([]) do
    IO.inspect("Successfully added all members")
    :ok
  end

  def add_member_to_db([ member | rest ]) do
    sub = Subscriber.insert_changeset(
      %Subscriber{}, %{
        email: member["email_address"],
        rid: member["merge_fields"]["RID"],
        parent_rid: member["merge_fields"]["PRID"],
        list: @list_id,
        mchimp_id: member["unique_email_id"]
      })

    case PlumaApi.Repo.insert(sub) do
      {:ok, _sub} ->
        add_member_to_db(rest)
      other ->
        IO.inspect("Something went wrong")
        IO.inspect(other)
        :error
    end
  end

  def check_health() do
    HTTPoison.get(
      @base_url <> "ping",
      [],
      [hackney: @hackney_auth]
    )
  end

  defp encode(sub = %Subscriber{}, false) do
    Jason.encode!(%{
      email_address: sub.email,
      status: "subscribed",
      merge_fields: %{
        ID: sub.id,
        RID: sub.rid
      }
    })
  end

  defp encode(sub = %Subscriber{}, true) do
    Jason.encode!(%{
      email_address: sub.email,
      status: "subscribed",
      tags: ["Test"],
      merge_fields: %{
        ID: sub.id,
        RID: sub.rid
      }
    })
  end

  @doc"""
  Applies MD5 encoding to a string - this is necessary in order to pass the email
  as a parameter to the Mailchimp API.
  """
  def hashify_email(email), do: :crypto.hash(:md5, email) |> Base.encode16 |> String.downcase

  @doc """
  Generates a random email address for use with the Mailosaur testing framework.
  """
  def generate_testing_email do
    Faker.Internet.slug() <> "." <> @mailosaur_server <> "@mailosaur.io"
  end

end
