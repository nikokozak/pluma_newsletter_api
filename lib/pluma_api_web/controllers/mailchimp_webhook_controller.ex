defmodule PlumaApiWeb.MailchimpWebhookController do
  require Logger
  require OK
  use PlumaApiWeb, :controller
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo
  alias PlumaApi.Mailchimp

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

  @doc """
  Handles "subscribe" and "unsubscribe" webhooks using `OK` to organize and rescue.

  Syncs RID's if there's a mismatch.
  """
  def handle(conn, params = %{ "type" => "subscribe" }) do
    OK.try do
      params = digest_webhook_params(params)
      subscriber <- insert_or_retrieve_subscriber(params)
      _synced_subscriber <- Mailchimp.sync_remote_and_local_RIDs(subscriber, params, @list_id)
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

  defp insert_or_retrieve_subscriber(params) do
    case find_in_db (params) do
      {:error, :local_not_found} -> insert_subscriber(params)
      {:ok, sub} -> {:ok, sub}
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

  defp insert_subscriber(params) do
    Subscriber.insert_changeset(%Subscriber{}, params)
    |> Repo.insert
    |> case do
      {:ok, sub} -> {:ok, sub}
      {:error, _chgst} -> {:error, :local_insert_failed}
    end
  end

  defp remove_subscriber(subscriber = %Subscriber{}) do
    case Repo.delete(subscriber) do
      {:ok, sub} -> {:ok, sub}
      {:error, _chgst} -> {:error, :local_delete_failed}
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
      case Mailchimp.tag_subscriber(subscriber.email, @list_id, [%{ name: "VIP", status: "active" }]) do
        {:ok, _response} -> {:ok, subscriber}
        {:error, _response} -> {:error, :error_tagging_subscriber}
      end
    else
      {:ok, :vip_not_granted}
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
