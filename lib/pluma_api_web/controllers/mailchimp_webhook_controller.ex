defmodule PlumaApiWeb.MailchimpWebhookController do
  require Logger
  require OK
  use PlumaApiWeb, :controller
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo
  alias PlumaApi.MailchimpRepo

  @moduledoc """
  Functions that handle Mailchimp webhooks. Used to keep our local database in sync
  with our Mailchimp Audience.

  At the moment, we only support `unsubscribe` and `subscribe` notifications by Mailchimp.

  Both webhooks get called whenever an embedded form or the admin interface adds a subscriber.
  """

  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  @doc """
  Mailchimp will ping the server to make sure the route provided is correct.
  """
  def test_get(conn, _params) do
    conn
    |> put_status(200)
    |> json("OK")
  end

  def handle(conn, params = %{ "type" => "subscribe" }) do
    OK.try do
      params = digest_webhook_params(params)
      subscriber <- insert_or_retrieve_subscriber(params)
      _synced_subscriber <- syncronize_rid(subscriber, params)
      _updated_parent <- update_parent(subscriber)
    after
      conn
      |> put_status(200)
      |> json(%{})
    rescue
      :local_insert_failed ->
        Logger.warn("Could not insert subscriber into local DB")
      :remote_update_error ->
        Logger.warn("Could not update remote RID")
      :local_update_error ->
        Logger.warn("Could not update local RID")
      :error_tagging_subscriber ->
        Logger.warn("Could not tag parent as VIP")
    end
  end

  def handle(conn, params = %{ "type" => "unsubscribe" }) do
    OK.try do
      params = digest_webhook_params(params)
      subscriber <- find_in_db(params)
      _deleted <- remove_subscriber(subscriber)
    after
      conn
      |> put_status(204)
      |> json(%{})
    rescue
      :local_not_found ->
        Logger.warn("Could not find subscriber in local DB")
        conn
        |> put_status(202)
        |> json(%{})
      :local_delete_failed ->
        Logger.warn("Error attempting to delete existing local subscriber")
    end
  end

  defp remove_subscriber(subscriber = %Subscriber{}) do
    case Repo.delete(subscriber) do
      {:ok, sub} -> {:ok, sub}
      {:error, _chgst} -> {:error, :local_delete_failed}
    end
  end

  defp insert_or_retrieve_subscriber(params) do
    case find_in_db (params) do
      {:error, :local_not_found} -> insert_subscriber(params)
      {:ok, sub} -> {:ok, sub}
    end
  end

  defp insert_subscriber(params) do
    Subscriber.insert_changeset(%Subscriber{}, params)
    |> Repo.insert
    |> case do
      {:ok, sub} -> {:ok, sub}
      {:error, _chgst} -> {:error, :local_insert_failed}
    end
  end

  defp find_in_db(params) do
    Subscriber.with_email(params.email)
    |> Repo.one
    |> case do
      nil -> {:error, :local_not_found}
      sub -> {:ok, sub}
    end
  end

  defp digest_webhook_params(params) do
    sub_data = params["data"]
    merge_fields = sub_data["merges"]
    %{
        email: sub_data["email"],
        mchimp_id: sub_data["id"],
        rid: merge_fields["RID"],
        parent_rid: merge_fields["PRID"],
        list: sub_data["list_id"]
    }
  end

  defp syncronize_rid(local_sub = %Subscriber{rid: ""}, external_sub), do: syncronize_rid(%{ local_sub | rid: nil }, external_sub)
  defp syncronize_rid(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: ""}) do
    OK.for do
      new_rid = Nanoid.generate()
      _remote_update <- update_remote(local_sub, %{ "RID": new_rid })
      local_update <- update_local(local_sub, %{ rid: new_rid })
    after
      {:ok, local_update}
    end
  end
  defp syncronize_rid(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: rid}) do
    OK.for do
      local_update <- update_local(local_sub, %{ rid: rid })
    after
      {:ok, local_update}
    end
  end
  defp syncronize_rid(local_sub = %Subscriber{rid: rid}, _external_sub = %{rid: ""}) do
    OK.for do
      _remote_update <- update_remote(local_sub, %{ "RID": rid })
    after
      {:ok, local_sub}
    end
  end
  defp syncronize_rid(local_sub = %Subscriber{rid: local_rid}, %{rid: remote_rid}) do 
    if not String.equivalent?(local_rid, remote_rid) do
      OK.for do
        _remote_update <- update_remote(local_sub, %{ "RID": local_rid })  
      after
        {:ok, local_sub}
      end
    else
      {:ok, local_sub}
    end
  end

  defp update_remote(subscriber = %Subscriber{}, updated_fields) when is_map(updated_fields) do
    MailchimpRepo.update_merge_field(subscriber.email, @list_id, updated_fields)
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, _error_response} -> {:error, :remote_update_error}
    end
  end

  defp update_local(subscriber = %Subscriber{}, updated_fields) do
    Subscriber.insert_changeset(subscriber, updated_fields)
    |> Repo.update
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, _chgst} -> {:error, :local_update_error}
    end
  end

  defp update_parent(child) do
    case get_parent(child) do
      {:ok, parent} -> maybe_award_vip(parent)
      {:error, nil} -> {:ok, :no_parent}
    end
  end

  defp get_parent(child) do
    if has_parent_rid(child) do
      Subscriber.with_rid(child.parent_rid)
      |> Repo.one
      |> OK.wrap
    else
      {:error, nil}
    end
  end

  defp maybe_award_vip(subscriber = %Subscriber{}) do
    subscriber = Repo.preload(subscriber, :referees)
    if length(subscriber.referees) == 3 do
      case MailchimpRepo.tag_subscriber(subscriber.email, @list_id, [%{ name: "VIP", status: "active" }]) do
        {:ok, _response} -> {:ok, subscriber}
        {:error, _response} -> {:error, :error_tagging_subscriber}
      end
    else
      {:ok, :vip_not_granted}
    end
  end

  @doc """
  Handles 'subscribe' and 'unsubscribe' Mailchimp events via parameter overrides. If the subscriber 
  has no RID (as in subscribers added via the admin panel), an RID is generated and the Mailchimp 
  subscriber is updated.

  Returns 200 for success otherwise 202 (necessary otherwise Mailchimp will keep trying).
  """
  def handle_event(conn, params = %{"type" => "subscribe"}) do
    data = digest_webhook_params(params)
    new_subscriber = Subscriber.insert_changeset(%Subscriber{}, data)

    Logger.info("New subscriber received: #{data.email}")
    

    case Repo.insert(new_subscriber) do
      {:ok, subscriber} ->
        maybe_update_rid(subscriber)
        maybe_tag_parent(subscriber)
        
        Logger.info("All operations completed successfully for #{Map.get(subscriber, :email)}")
        conn
        |> put_status(200)
        |> json(%{ status: "created", email: subscriber.email })
      {:error, error} ->
        Logger.warn("Something went wrong while trying to insert the new subscriber - likely a duplicate email")
        IO.inspect(error)

        conn
        |> put_status(202)
        |> json(%{ status: "error", detail: inspect(error) })
    end
  end

  def handle_event(conn, params = %{"type" => "unsubscribe"}) do
    data = digest_webhook_params(params)
    sub = Subscriber.with_email(data.email) 
          |> Repo.one

    Logger.info("New unsubscribe event received: #{params["data"]["email"]}")
    Logger.info("Attempting to delete #{inspect(sub)}")

    conn
    |> maybe_delete_subscriber_from_db(sub)
  end

  defp maybe_delete_subscriber_from_db(conn, nil) do
    Logger.info("No subscriber with given email found for unsubscribe in DB")
    conn
    |> put_status(202)
    |> json(%{ status: "error", detail: "no user" })
  end

  defp maybe_delete_subscriber_from_db(conn, sub) do
    case Repo.delete(sub) do
      {:ok, deleted} ->
        Logger.info("Successfully deleted #{Map.get(deleted, :email)} from database.")
        conn
        |> put_status(200)
        |> json(%{ status: "deleted", email: Map.get(deleted, :email) })
      {:error, changeset} ->
        Logger.warn("There was an error attempting to delete a user from the database.")
        IO.inspect(changeset)
        conn
        |> put_status(202)
        |> json(%{ status: "error", detail: inspect(changeset) })
    end
  end

  defp maybe_update_rid(subscriber = %Subscriber{rid: ""}), do: maybe_update_rid(%{ subscriber | rid: nil })
  defp maybe_update_rid(subscriber = %Subscriber{rid: nil}) do
    Logger.info("Now attempting to update RID for #{Map.get(subscriber, :email)}")
    new_rid = Nanoid.generate()
    response = MailchimpRepo.update_merge_field(subscriber.email, @list_id, %{ "RID": new_rid })
    case response do
      {:ok, _reponse_body} ->
        Logger.info("Updated RID field for #{Map.get(subscriber, :email)} in Mailchimp successfully")
        Subscriber.insert_changeset(subscriber, %{rid: new_rid})
        |> Repo.update
      {:error, error_response} ->
        Logger.warn("There was an error remotely updating RID field for #{Map.get(subscriber, :email)}")
        IO.inspect(error_response)
    end
  end

  defp maybe_update_rid(_other) do 
    Logger.info("No RID update required.")
    :ok
  end

  defp maybe_tag_parent(child) do
    if has_parent_rid(child) do
      parent = 
        Subscriber.with_rid(child.parent_rid)
        |> Subscriber.preload_referees
        |> Repo.one
      
      maybe_make_vip(parent)
    end
  end

  defp maybe_make_vip(nil) do
    Logger.info("Parent has unsubscribed from Pluma")
    :ok
  end
  defp maybe_make_vip(parent) do
    Logger.info("Now checking if parent has enough children for VIP clasification")
    case Map.get(parent, :referees) do
      nil -> :ok
      other ->
        if length(other) == 3 do
          {:ok, _} = 
            MailchimpRepo.tag_subscriber(parent.email, @list_id, [%{ name: "VIP", status: "active" }])
          Logger.info("Successfully tagged parent as VIP")
        end
    end
  end

  defp has_parent_rid(child) do
    if not is_nil(child.parent_rid) and String.length(child.parent_rid) != 0 do
      true
    else
      false
    end
  end
  
end
