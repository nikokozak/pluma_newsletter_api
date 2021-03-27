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

  defp digest_webhook_params(params) do
    sub_data = params["data"]
    merge_fields = sub_data["merges"]
    status = type_to_status(params["type"])
    ip = Map.get(sub_data, "ip_signup") || Map.get(sub_data, "ip_opt", "")
    %{
      email: sub_data["email"],
      list: sub_data["list_id"] || @list_id,
      rid: merge_fields["RID"],
      parent_rid: merge_fields["PRID"],
      fname: merge_fields["FNAME"],
      lname: merge_fields["LNAME"],
      status: status,
      ip_signup: ip
    }
  end

  defp type_to_status(type) do
    case type do
      "subscribe" -> "subscribed"
      "unsubscribe" -> "unsubscribed"
    end
  end

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
    case Mailchimp.webhook_subscribe(params) do
      {:ok, _sub} -> 
        Logger.info("Subscribe webhook for #{params.email} processed succesfully.")
        webhook_response(conn, 200)
      {:error, error} ->
        log_error(error)
        webhook_response(conn, 202)
    end
  end

  def handle(conn, params = %{ "type" => "unsubscribe" }) do
    params = digest_webhook_params(params)
    case Mailchimp.webhook_unsubscribe(params) do
      {:ok, _deleted} -> 
        Logger.info("Unsubscribe webhook for #{params.email} processed succesfully.")
        webhook_response(conn, 200)
      {:error, error} -> 
        log_error(error)
        webhook_response(conn, 202)
    end
  end

  def log_error({:local_insert_error, {params, chgst}}) do
    Logger.warn("Webhook: Error trying to insert #{params.email} into local DB. Changeset
      for insertion errors: #{chgst.errors}")
  end
  def log_error({:local_upsert_error, {sub, chgst}}) do
    Logger.warn("Webhook: Error trying to updatsert in local db for subscriber #{sub.email}. Changeset
      for upsert errors: #{chgst.errors}")
  end
  def log_error({:mc_upsert_error, {sub, error_response}}) do
    Logger.warn("Webhook: Error trying to update Mailchimp subscriber via API for #{sub.email}.
      Error response: #{error_response["title"]}")
  end
  def log_error({:mc_error_tagging, {sub, response}}) do
    Logger.warn("Webhook: Error tagging Mailchimp subscriber #{sub.email}. Response was:
      #{response["title"]}")
  end

  defp webhook_response(conn, code) do
    conn |> put_status(code) |> json("OK")
  end
  
end
