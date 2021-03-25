defmodule PlumaApi.Mailchimp.Syncer do
  alias PlumaApi.Subscriber 
  alias PlumaApi.Mailchimp
  require OK

  @doc """
  Synchronizes remote and local RID values, given a local subscriber (`Subscriber`) and 
  an external subscriber (a `map` of subscriber parameters). Used with the webhook interface.

  Can handle missing RID's on both ends, with a bias towards a local RID. Will correct incongruent
  RID's as well.

  Returns `{:ok, subscriber}` where subscriber is the synced subscriber. 
  Also returns `{:error, {:remote_update_error, {sub, response}}}` and `{:error, {:local_update_error, {sub, chgst}}}` in case
  there's a problem communicating with the remote API or local DB.
  """
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: ""}, external_sub, list_id), do: sync_remote_and_local_RIDs(%{ local_sub | rid: nil }, external_sub, list_id)
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: ""}, list_id) do
    OK.for do
      new_rid = Nanoid.generate()
      _remote_update <- update_remote(local_sub, %{ "RID": new_rid }, list_id)
      local_update <- update_local(local_sub, %{ rid: new_rid })
    after
      {:ok, local_update}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: rid}, _list_id) do
    OK.for do
      local_update <- update_local(local_sub, %{ rid: rid })
    after
      {:ok, local_update}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: rid}, _external_sub = %{rid: ""}, list_id) do
    OK.for do
      _remote_update <- update_remote(local_sub, %{ "RID": rid }, list_id)
    after
      {:ok, local_sub}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: local_rid}, %{rid: remote_rid}, list_id) do 
    if not String.equivalent?(local_rid, remote_rid) do
      OK.for do
        _remote_update <- update_remote(local_sub, %{ "RID": local_rid }, list_id)  
      after
        {:ok, local_sub}
      end
    else
      {:ok, local_sub}
    end
  end
  
  defp update_remote(subscriber = %Subscriber{}, updated_fields, list_id) when is_map(updated_fields) do
    Mailchimp.update_merge_field(subscriber.email, list_id, updated_fields)
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, error_response} -> {:error, {:remote_update_error, {subscriber, error_response}}}
    end
  end

  defp update_local(subscriber = %Subscriber{}, updated_fields) do
    Subscriber.insert_changeset(subscriber, updated_fields)
    |> PlumaApi.Repo.update
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, chgst} -> {:error, {:local_update_error, {subscriber, chgst}}}
    end
  end

end
