defmodule PlumaApi.MailchimpRepo do
  alias PlumaApi.Subscriber
  @api_key Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_key)
  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @api_server Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_server)
  @base_url "https://" <> @api_server <> ".api.mailchimp.com/3.0/"
  @hackney_auth [basic_auth: {"plumachile", @api_key}]

  @moduledoc """
  A set of functions for interacting with the Mailchimp API. The `list_id`, which
  is necessary for most of these functions, refers to the specific audience list we
  wish to work with, and can be found in the `main_list_id` variable of the `config.exs`
  file.

  The hackney option is passed into HTTPoison internally in order to generate the correct authorization
  protocol.

  All functions return either a `{:ok, response_body :: %{}}` or `{:error, response_body :: %{}}`
  tuple. This is done to save us some effort in checking the return status codes, which vary
  from API call to API call (i.e. some return 200 vs. 204). 

  Internally, all functions will raise in case of connection failures (but won't raise if a resource
  wasn't found by the Mailchimp API for example).
  """

  @type success_response() :: HTTPoison.Response.t()
  @type error_response() :: HTTPoison.Response.t()

  @spec check_health() :: success_response | error_response
  @spec get_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response
  @spec add_to_audience(subscriber_data :: binary, list_id :: String.t) :: success_response | error_response
  @spec tag_subscriber(email :: String.t, list_id :: String.t, tags :: list(%{name: String.t, status: String.t})) :: success_response | error_response
  @spec create_merge_field(list_id :: String.t, field_name :: String.t, field_type :: String.t) :: success_response | error_response
  @spec update_merge_field(email :: String.t, list_id :: String.t, merge_fields :: map) :: success_response | error_response
  @spec check_exists(email :: String.t, list_id :: String.t) :: success_response | error_response
  @spec archive_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response
  @spec delete_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response

  @doc """
  Checks to see if the Mailchimp API is responding.

  Returns an `{:ok, %{"health_status" => health_status :: string}}` if successful, and
  `{:error, error_body :: %{}}` if not.
  """
  def check_health() do
    HTTPoison.get!(
      @base_url <> "ping",
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Applies MD5 encoding to a string - this is necessary in order to pass the email
  as a parameter to the Mailchimp API.
  """
  def hashify_email(email), do: :crypto.hash(:md5, String.downcase(email)) |> Base.encode16 |> String.downcase

  @doc """
  Get the details for a given email address if present in a Mailchimp audience.

  Returns `{:ok, response_body}` if successful, otherwise `{:error, error}`.
  """
  def get_subscriber(email, list_id) do
    HTTPoison.get!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Adds a given `Subscriber` to the mailchimp audience. If `test` parameter is passed as "true",
  then the `Subscriber` is assigned a "Test" tag in the audience, making it easy to remove them.

  Returns a `{:ok, repsonse_body}` struct if successful, otherwise `{:error, :error_response}`
  """
  def add_to_audience(subscriber_data, list_id) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members",
      subscriber_data,
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Adds tags to a given subscriber in a Mailchimp audience.

  Returns a `HTTPoison.Response{status_code: 204}` struct if successful.
  """
  def tag_subscriber(email, list_id, tags) when is_list(tags) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email) <> "/tags",
      Jason.encode(%{ tags: tags, is_syncing: false }) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Creates a new Merge Field for subscribers in a list. By default the new merge field
  is not public and is not a required field.

  Returns a `HTTPoison.Response{status_code: 200}` if successful.

  Of interest is the `merge_id` value returned by Mailchimp on success, which is 
  required if we want to update the merge field itself in the future.
  """
  def create_merge_field(list_id, field_name, field_type) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/merge-fields",
      Jason.encode(%{ 
        name: field_name,
        type: field_type,
        required: false,
        public: false
      }),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Updates a set of Merge Fields (custom mailchimp subscriber fields) for a given subscriber.
  
  Returns a `HTTPoison.Response{status_code: 200}` struct if successful.
  """
  def update_merge_field(email, list_id, merge_fields) when is_map(merge_fields) do
    HTTPoison.patch!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      Jason.encode(%{merge_fields: merge_fields}) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Check whether a given email exists in the provided list.

  Returns `boolean` true or false.
  """
  def check_exists(email, list_id) do
    HTTPoison.get!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Remove a subscriber from a given Mailchimp audience list.

  Returns `{:ok, %{}}` if successful, `{:error, error}` otherwise.
  """ 
  def archive_subscriber(email, list_id) do
    HTTPoison.delete!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  Permanently delete a subscriber from a given Mailchimp audience list.

  Deleted subscribers CANNOT be reimported, unlike archived subs.

  Returns `{:ok, %{}}` if successful, `{:error, error}` otherwise.
  """ 
  def delete_subscriber(email, list_id) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email) <> "/actions/delete-permanent",
      Jason.encode(%{}) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
  end

  @doc """
  WARNING - retrieves up to 1000 subscribers from the main Mailchimp list, 
  wipes out the local database, and recursively re-populates the local database
  with Mailchimp information. 

  AVOID USING FOR NOW, LARGELY UNTESTED/REDUNDANT.
  TODO :: Write CSV importer
  """
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

  defp add_members_to_db(members) when is_list(members), do: add_member_to_db(members)

  defp add_member_to_db([]) do
    IO.inspect("Successfully added all members")
    :ok
  end

  defp add_member_to_db([ member | rest ]) do
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


end
