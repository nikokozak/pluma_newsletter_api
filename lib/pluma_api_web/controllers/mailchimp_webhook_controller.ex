defmodule PlumaApiWeb.MailchimpWebhookController do
  require Logger
  require OK
  use PlumaApiWeb, :controller
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

  If a subscriber is already present, it will attempt to sync RID's with the external sub.

  A call is made to tag the parent as VIP if the parent has 3 referees.

  Syncs RID's if there's a mismatch.
  """
  def handle(conn, params = %{ "type" => "subscribe" }) do
    params = digest_webhook_params(params)
    case Mailchimp.confirm_subscription(params, @list_id) do
      {:ok, _sub} -> webhook_response(conn, 200)
      {:error, error} ->
        log_error(error)
        webhook_response(conn, 202)
    end
  end

  def handle(conn, params = %{ "type" => "unsubscribe" }) do
    case Mailchimp.unsubscribe(params["data"]["email"]) do
      {:ok, _deleted} -> webhook_response(conn, 204)
      {:error, error} -> 
        log_error(error)
        webhook_response(conn, 202)
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

  def log_error({:local_not_found, email}) do
    Logger.warn("Error trying to unsubscribe #{email} from local DB. #{email} not
      registered locally.")
  end
  def log_error({:local_insert_failed, {params, chgst}}) do
    Logger.warn("Error trying to insert #{params.email} into local DB. Changeset
      for insertion: #{chgst.errors}")
  end
  def log_error({:remote_update_error, {sub, error_response}}) do
    Logger.warn("Error trying to update Mailchimp subscriber via API for #{sub.email}.
      Error response: #{error_response["title"]}")
  end
  def log_error({:local_update_error, {sub, chgst}}) do
    Logger.warn("Error trying to update local db for subscriber #{sub.email}. Changeset
      for insertion: #{chgst.errors}")
  end
  def log_error({:error_tagging_subscriber, {sub, response}}) do
    Logger.warn("Error tagging Mailchimp subscriber #{sub.email}. Response was:
      #{response["title"]}")
  end
  def log_error({:local_delete_failed, {sub, chgst}}) do
    Logger.warn("Error trying to delete a local subscriber #{sub.email}. Changeset 
      for deletion: #{chgst.errors}")
  end

  defp webhook_response(conn, code) do
    conn |> put_status(code) |> json(%{})
  end
  
end
