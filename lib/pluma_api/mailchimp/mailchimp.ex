defmodule PlumaApi.Mailchimp do
  alias PlumaApi.Mailchimp.Repo, as: MR
  alias PlumaApi.Subscriber
  require OK

  @doc """
  Adds a subscriber to a given Mailchimp audience.
  `subscriber` -> a map of subscriber values or a `Subscriber` or a `NewSubscriber` struct.
  `list_id` -> the mailchimp list to which the subscriber will be added.
  `status` -> one-of "pending" or "subscribed". "pending" subscribers are not formally in the 
              Mailchimp list: instead, a confirmation request is sent to the subscriber. If
              "subscribed", the API invokes a Webhook which is handled by our server, and the 
              subscriber is formally added to the list.
  `test?` -> whether to include a "Test" tag in the data passed to Mailchimp. Useful in case 
              we need to manually delete test-created subscribers.

  Returns `{:ok, body}` or `{:error, error_body}`
  """
  def add_to_list(subscriber = %Subscriber{}), do: add_to_list(subscriber, subscriber.list)
  def add_to_list(subscriber = %Subscriber{}, list_id) do
    Jason.encode!(subscriber)
    |> MR.add_to_list(list_id)
  end

  @doc """
  Creates a new subscription. To do so, checks if an email already exists in our local database,
  resolves RID collisions, and calls the Mailchimp API to insert a new subscriber.

  *Note*: New subscribers are NOT inserted into the local database. Rather, they are added to 
  the desired Mailchimp list as `"pending"`. Inserting subscribers into our local DB and thus resolving
  the flow is the responsibility of `confirm_subscription`.

  **Parameters:**
  - `params`: a map of params that are validated by `Subscriber.validate_params` and turned into a `%Subscriber{}` struct if valid.
  - `list_d`: list to which we want to add the subscriber.

  **Returns:**
  - `{:ok, Jason.decode!(mailchimp_response_body)}`
  - `{:error, Jason.decode!(mailchimp_response_body)}`
  - `{:error, {:local_email_found, %Subscriber{}}}`
  - `{:error, {:validation, incorrect_changeset}}`
  """
  def subscribe(%{email: email} = params) do
    OK.for do
      _ <- ensure_not_in_db(email)
      local <- add_to_db(params)
      response <- upsert_remote(local)
      _ <- update_parent(local, local.list)
    after
      response
    end
  end

  @doc """
  Handles a new subscription as submitted via a Mailchimp Webhook. Will upsert a local
  `Subscriber`, and then upsert the remote record (in order to update `RID` field), as
  well as potentially tag the remote record.

  **Parameters:**
  - `params`: a digested (i.e. compatible with `Subscriber.changeset/2` and schema map of
    values. Crucially, should include `"email"`, `"status"`, and `"list"`.

  **Returns:**
  - `{:ok, mailchimp_response_body}` on success.
  - `{:error, {:local_upsert_error, chgst}}` on error updating the local `Subscriber`.
  - `{:error, {:mc_upsert_error, resp}}` on error upserting the remote record with the 
    new `Subscriber` details.
  - `{:error, {:mc_error_tagging, {subscriber, response}}}` on error tagging the parent
    when VIP status achieved.
  """
  def webhook_subscribe(params) do
    OK.for do
      local <- upsert_local(params)
      response <- upsert_remote(local)
      _ <- update_parent(local, local.list)
    after
      response
    end
  end

  @doc """
  Handles unsubscribe Mailchimp Webhooks. Will upsert a local `Subscriber` with a
  "unsubscribed" `status`.

  **Parameters:**
  - `params`: a digested (i.e. compatible with `Subscriber.changeset/2` and schema map of
    values. Crucially, should include `"email"`, `"status"`, and `"list"`.

  **Returns:**
  - `{:ok, local_sub}` on success.
  - `{:error, {:local_upsert_error, chgst}}` on error updating the local `Subscriber`.
  """
  def webhook_unsubscribe(params) do
    OK.for do
      local <- upsert_local(params) 
    after
      local
    end
  end

  defp ensure_not_in_db(email) do
    Subscriber.with_email(email)
    |> PlumaApi.Repo.one
    |> case do
      nil -> {:ok, :not_found}
      sub -> {:error, {:local_sub_found, sub}}
    end
  end

  defp add_to_db(params) do
    Subscriber.changeset(%Subscriber{}, params)
    |> PlumaApi.Repo.insert
    |> case do
      {:ok, sub} -> {:ok, sub}
      {:error, chgst} -> {:error, {:local_insert_error, chgst}}
    end
  end

  defp upsert_local(params) do
    Subscriber.with_email(params.email)
    |> PlumaApi.Repo.one
    |> case do
      nil -> %Subscriber{}
      sub -> sub
    end
    |> Subscriber.changeset(params)
    |> PlumaApi.Repo.insert_or_update
    |> case do
      {:ok, sub} -> {:ok, sub}
      {:error, chgst} -> {:error, {:local_upsert_error, chgst}}
    end
  end

  defp upsert_remote(%Subscriber{} = sub) do
    data = Jason.encode!(sub)
    case MR.upsert_member(sub.email, data, sub.list) do
      {:ok, resp} -> {:ok, resp}
      {:error, resp} -> {:error, {:mc_upsert_error, resp}}
    end
  end

  # Returns 
  # {:ok, :no_parent} | 
  # {:ok, :vip_not_granted} | 
  # {:ok, %Subscriber{}} (if granted) | 
  # {:error, {:error_tagging_subscriber, {subscriber, error_response}}}
  defp update_parent(child, list_id) do
    case get_parent(child) do
      {:ok, parent} -> maybe_award_vip(parent, list_id)
      {:error, nil} -> {:ok, :no_parent}
    end
  end

  defp get_parent(child) do
    if has_parent_rid(child) do
      Subscriber.with_rid(child.parent_rid)
      |> PlumaApi.Repo.one
      |> OK.wrap # Wrap in {:ok, ...}
    else
      {:error, nil}
    end
  end

  defp maybe_award_vip(subscriber = %Subscriber{}, list_id) do
    subscriber = PlumaApi.Repo.preload(subscriber, :referees)
    if length(subscriber.referees) == 3 do
      case MR.tag_subscriber(subscriber.email, list_id, [%{ name: "VIP", status: "active" }]) do
        {:ok, _response} -> {:ok, subscriber}
        {:error, response} -> {:error, {:mc_error_tagging, {subscriber, response}}}
      end
    else
      {:ok, :vip_not_granted}
    end
  end

  defp has_parent_rid(child) do
    if not is_nil(child.parent_rid) and String.length(child.parent_rid) != 0, do: true, else: false
  end

end
