defmodule PlumaApiWeb.MailchimpWebhookController do
  require Logger
  use PlumaApiWeb, :controller
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo
  alias PlumaApi.MailchimpRepo

  @moduledoc """
  Functions that handle Mailchimp webhooks. Used to keep our local database in sync
  with our Mailchimp Audience.

  At the moment, we only support `unsubscribe` and `subscribe` notifications by Mailchimp.
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
