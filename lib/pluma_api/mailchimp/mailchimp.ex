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
  def add_to_list(subscriber = %Subscriber{}, list_id) do
    Jason.encode!(subscriber)
    |> MR.add_to_audience(list_id)
  end
  def add_to_list(params, list_id) when is_map(params) do
    case Subscriber.validate_params(params) do
      {:ok, new_sub} -> add_to_list(new_sub, list_id)
      error -> error
    end
  end
  def add_to_list(email, list_id, status, test?), do: add_to_list(%{"email" => email}, list_id, status, test?)

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
  - `{:error, {:validation, incorrect_changeset}}`
  - `{:error, {:local_email_found, %Subscriber{}}}`
  """
  def subscribe(params, list_id) do
    OK.for do
      validated <- Subscriber.validate_params(params)
      safe <- ensure_doesnt_exist(validated)
      result <- add_to_list(safe, list_id)
    after
      result 
    end
  end

  defp ensure_doesnt_exist(subscriber = %Subscriber{}) do
    OK.for do
      _ <- ensure_email_not_in_db(subscriber)
      safe_sub = ensure_no_rid_collision(subscriber)
    after
      safe_sub
    end
  end

  defp ensure_email_not_in_db(subscriber) do
    Subscriber.with_email(subscriber.email)
    |> PlumaApi.Repo.one
    |> case do
      nil -> {:ok, subscriber}
      sub -> {:error, {:local_email_found, sub}}
    end
  end

  defp ensure_no_rid_collision(subscriber) do
    Subscriber.with_rid(subscriber.rid)
    |> PlumaApi.Repo.one
    |> case do
      nil -> {:ok, subscriber}
      _sub -> {:ok, assign_new_rid(subscriber)}
    end
  end

  defp assign_new_rid(subscriber), do: %{ subscriber | rid: Nanoid.generate() }

  @doc """
  Confirms a subscription. In doing so, it adds a subscriber to our database reflecting the details
  of the subscriber present in Mailchimp. If the subscriber is already present, they're retrieved and
  potential RID collisions are resolved (with a bias towards local RID's).

  **Parameters:**
  - `params`: A map of parameters to insert. These get validated by the `Subscriber.validate_params` function,
              which turns them into a `%Subscriber{}` struct.
  - `list_id`: The list on which we're operating. Used for syncing rid's if necessary.

  **Returns:**
  - `{:ok, %Subscriber{}}`
  - `{:error, {:validation, incorrect_changeset}}`
  - `{:error, {:local_insert_failed, {params, chgst}}}`
  - `{:error, {:error_tagging_subscriber, {subscriber, error_response}}}`
  """
  def confirm_subscription(params, list_id) do
    OK.for do
      validated <- Subscriber.validate_params(params)
      subscriber <- insert_or_retrieve_subscriber(validated)
      synced <- sync_rids(subscriber, validated, list_id)
      _updated_parent <- update_parent(synced, list_id)
    after
      synced
    end
  end

  defp insert_or_retrieve_subscriber(params = %Subscriber{}) do
    case find_in_db (params) do
      {:error, :local_not_found} -> insert_subscriber(params)
      {:ok, sub} -> {:ok, sub}
    end
  end

  defp find_in_db(params = %Subscriber{}), do: find_in_db(params.email)
  defp find_in_db(email) do
    Subscriber.with_email(email)
    |> PlumaApi.Repo.one
    |> case do
      nil -> {:error, :local_not_found}
      sub -> {:ok, sub}
    end
  end

  defp insert_subscriber(params) do
    PlumaApi.Repo.insert(params)
    |> case do
      {:ok, sub} -> {:ok, sub}
      {:error, chgst} -> {:error, {:local_insert_failed, {params, chgst}}}
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
        {:error, response} -> {:error, {:error_tagging_subscriber, {subscriber, response}}}
      end
    else
      {:ok, :vip_not_granted}
    end
  end

  defp has_parent_rid(child) do
    if not is_nil(child.parent_rid) and String.length(child.parent_rid) != 0, do: true, else: false
  end

  def unsubscribe(email) do
    OK.for do
      subscriber <- find_in_db(email)
      _deleted <- remove_subscriber(subscriber)
    after
      subscriber
    end
  end

  defp remove_subscriber(subscriber = %Subscriber{}) do
    case PlumaApi.Repo.delete(subscriber) do
      {:ok, sub} -> {:ok, sub}
      {:error, chgst} -> {:error, {:local_delete_failed, {subscriber, chgst}}}
    end
  end

  @doc """
  Synchronizes remote and local RID values, given a local subscriber (`Subscriber`) and 
  an external subscriber (a `map` of subscriber parameters). Used with the webhook interface.

  Can handle missing RID's on both ends, with a bias towards a local RID. Will correct incongruent
  RID's as well.

  Returns `{:ok, subscriber}` where subscriber is the synced subscriber. 
  Also returns `{:error, {:remote_update_error, {sub, response}}}` and `{:error, {:local_update_error, {sub, chgst}}}` in case
  there's a problem communicating with the remote API or local DB.
  """
  def sync_rids(local_sub = %Subscriber{}, remote_sub, list_id), do: PlumaApi.Mailchimp.Syncer.sync_remote_and_local_RIDs(local_sub, remote_sub, list_id)

end
