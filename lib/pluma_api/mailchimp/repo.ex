defmodule PlumaApi.Mailchimp.Repo do
  @api_key Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_key)
  @api_server Keyword.get(Application.get_env(:pluma_api, :mailchimp), :api_server)
  @base_url "https://" <> @api_server <> ".api.mailchimp.com/3.0/"
  @hackney_auth [basic_auth: {"plumachile", @api_key}]

  @default_success_code 200

  @moduledoc """
  A set of functions for interacting with the Mailchimp API. The `list_id`, which
  is necessary for most of these functions, refers to the specific audience list we
  wish to work with, and can be found in the `main_list_id` variable of the `config.exs`
  file.

  The hackney option is passed into HTTPoison internally in order to generate the correct authorization
  protocol.

  All functions return a `HTTPoison.Response{}` struct. In order to assert success,
  the `status_code` of the struct can be checked against Mailchimp API guidelines.

  Internally, all functions will raise in case of connection failures (but won't raise if a resource
  wasn't found by the Mailchimp API for example).
  """

  @type success_response() :: {:ok, map}
  @type error_response() :: {:error, map}

  @spec check_health() :: success_response | error_response
  @spec get_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response
  @spec add_to_list(subscriber_data :: binary, list_id :: String.t) :: success_response | error_response
  @spec tag_subscriber(email :: String.t, list_id :: String.t, tags :: list(%{name: String.t, status: String.t})) :: success_response | error_response
  @spec update_merge_field(email :: String.t, list_id :: String.t, merge_fields :: map) :: success_response | error_response
  @spec check_exists(email :: String.t, list_id :: String.t) :: boolean
  @spec archive_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response
  @spec delete_subscriber(email :: String.t, list_id :: String.t) :: success_response | error_response

  @doc """
  Applies MD5 encoding to a string - this is necessary in order to pass the email
  as a parameter to the Mailchimp API.
  """
  def hashify_email(email), do: :crypto.hash(:md5, String.downcase(email)) |> Base.encode16 |> String.downcase

  @doc """
  Checks to see if the Mailchimp API is responding.
  """
  def check_health() do
    HTTPoison.get!(
      @base_url <> "ping",
      [],
      [hackney: @hackney_auth]
    )
    |> process_response
  end

  @doc """
  Check whether a given email exists in the provided list.
  """
  def check_exists(email, list_id) do
    HTTPoison.get!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
    |> case do
      %{status_code: 200} -> true
      _other -> false
    end
  end

  @doc """
  Get the details for a given email address if present in a Mailchimp audience.
  """
  def get_subscriber(email, list_id) do
    HTTPoison.get!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
    |> process_response
  end

  @doc """
  Adds a given `Subscriber` to the mailchimp audience. If `test` parameter is passed as "true",
  then the `Subscriber` is assigned a "Test" tag in the audience, making it easy to remove them.

  Returns a `{:ok, repsonse_body}` struct if successful, otherwise `{:error, :error_response}`
  """
  def add_to_list(subscriber_data, list_id) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members",
      subscriber_data,
      [],
      [hackney: @hackney_auth]
    )
    |> process_response
  end

  @doc """
  Adds to or updates a member in the given Mailchimp list. 

  **Note**: As part of the `subscriber_data` provided, a `status_if_new` must be included,
  and must be one of `"subscribed", "unsubscribed", "pending", "archived", or "transactional"`.

  Please refer to the Mailchimp API Docs for allowed fields. *Note that `tags` cannot be passed*
  https://mailchimp.com/developer/marketing/api/list-members/add-or-update-list-member/

  Returns a `{:ok, reponse_body}` | `{:error, error_response}`.
  """
  def upsert_member(email, subscriber_data, list_id) do
    HTTPoison.put!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      subscriber_data,
      [],
      [hackney: @hackney_auth]
    )
    |> process_response
  end

  @doc """
  Adds tags to a given subscriber in a Mailchimp audience. Tags are passed as a list of
  `maps`, eg: `[%{ name: "VIP", status: "active" }]`

  Returns a `HTTPoison.Response{status_code: 204}` struct if successful.
  """
  def tag_subscriber(email, list_id, tags) when is_list(tags) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email) <> "/tags",
      Jason.encode(%{ tags: tags, is_syncing: false }) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
    |> process_response(204)
  end

  @doc """
  Updates a set of Merge Fields (custom mailchimp subscriber fields) for a given subscriber.
  
  `merge_fields` is a `map` of Merge Fields and the new value desired. Eg. `%{"PRID" => "cokoo"}`

  Returns a `HTTPoison.Response{status_code: 200}` struct if successful.
  """
  def update_merge_field(email, list_id, merge_fields) when is_map(merge_fields) do
    HTTPoison.patch!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      Jason.encode(%{merge_fields: merge_fields}) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
    |> process_response
  end

  @doc """
  Remove a subscriber from a given Mailchimp audience list.

  Returns `HTTPoison.Response{status_code: 204}` if successful.
  """ 
  def archive_subscriber(email, list_id) do
    HTTPoison.delete!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email),
      [],
      [hackney: @hackney_auth]
    )
    |> process_response(204)
  end

  @doc """
  Permanently delete a subscriber from a given Mailchimp audience list.

  Deleted subscribers CANNOT be reimported, unlike archived subs.

  Returns `HTTPoison.Response{status_code: 204}` if successful.
  """ 
  def delete_subscriber(email, list_id) do
    HTTPoison.post!(
      @base_url <> "lists/" <> list_id <> "/members/" <> hashify_email(email) <> "/actions/delete-permanent",
      Jason.encode(%{}) |> elem(1),
      [],
      [hackney: @hackney_auth]
    )
    |> process_response(204)
  end

  defp process_response(response, success_code \\ @default_success_code) do
    case response do
      %{ status_code: ^success_code, body: body } -> {:ok, decode_response_body(body)}
      %{ status_code: _error_code, body: body } -> {:error, decode_response_body(body)}
    end
  end

  defp decode_response_body(""), do: %{}
  defp decode_response_body(body), do: Jason.decode!(body)

end
