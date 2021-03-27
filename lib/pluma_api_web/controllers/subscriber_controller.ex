defmodule PlumaApiWeb.SubscriberController do
  require Logger
  require OK
  use PlumaApiWeb, :controller  
  alias PlumaApiWeb.ErrorView
  alias PlumaApi.{Subscriber, Repo, Mailchimp}

  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  @doc """
  Retrieves a `%Subscriber{}` from the local database and returns it in JSON format. 
  """
  def get_subscriber(conn, params) do
    OK.try do
      found <- find_in_db(params)
    after
      conn
      |> put_status(200)
      |> render("details.json", subscriber: found)
    rescue
      :not_found ->
        conn
        |> put_status(404)
        |> put_view(ErrorView)
        |> render("404.json", message: "Could not find subscriber")
    end
  end

  defp find_in_db(%{ "email" => email }) do
    Subscriber.with_email(email) |> Subscriber.preload_referees |> Repo.one |> OK.required(:not_found)
  end
  defp find_in_db(%{ "rid" => rid }) do
    Subscriber.with_rid(rid) |> Subscriber.preload_referees |> Repo.one |> OK.required(:not_found)
  end

  @doc """
  Adds a subscriber to the Mailchimp API as "pending" confirmation. Call parameters are ingested
  into a `%NewSubscriber{}` struct, which is then encoded using a custom implementation of the 
  `Jason` encoder into a format agreeable to Mailchimp. Connection errors to either our Database
  or the Mailchimp API will be raised.

  ## Parameters
  - `conn` - `Plug.Conn.t`
  - `params` - A `map` of subscriber data. Note that this data will be passed into a 
               The only *required* attribute is a valid-format email.

  ## Returns
  All returns are technically `Plug.Conn.t`, but the status codes and bodies are outlined here
  for convenience.

  - Status: `200`, Body: `Jason.encode!(%NewSubscriber{})`
  - Status: `400`, Body: `Jason.encode!(%{ status: :error, type: :validation, detail: Keyword.t })`
                    *detail* here is a list of fields that had validation errors, i.e. `["email", "fname"]`
  - Status: `400`, Body: `Jason.encode!(%{ status: :error, type: :email_exists, detail: email })` - Email exists in our local DB.
  - Status: `400`, Body: `Jason.encode!(%{ status: :error, type: :mc_sub_pending, detail: email })` - Awaiting subscriber confirmation.
  - Status: `400`, Body: `Jason.encode!(%{ status: :error, type: :mc_unknown, detail: mailchimp_status })` - Unhandled error.
  """
  @spec add_subscriber(conn :: Plug.Conn.t, params :: map) :: %Plug.Conn{}
  def add_subscriber(conn, params) do
    params = digest_add_subscriber_params(params)
    case Mailchimp.subscribe(params) do
      {:ok, response} ->
        Logger.info("Successfully subscribed #{response["email_address"]}")
        respond(conn, 200, response)
      {:error, error} ->
        respond(conn, 400, handle_error(:add_subscriber, error))
    end
  end

  defp digest_add_subscriber_params(params) do
    %{
      email: getopt(params, "email"),
      fname: getopt(params, "fname"),
      lname: getopt(params, "lname"),
      rid: getopt(params, "rid"),
      parent_rid: getopt(params, "prid"),
      ip_signup: getopt(params, "ip_signup"),
      list: Map.get(params, "list") || @list_id,
      status: "pending"
    }
  end

  defp getopt(map, key), do: Map.get(map, key, "")
  
  defp handle_error(:add_subscriber, %{"status" => 400, "detail" => detail}) do
    Logger.warn("Error adding subscriber to MC audience. \"#{detail}\". Likely waiting on confirmation email.")
    %{status: :error, type: :mc_sub_pending, detail: detail}
  end
  defp handle_error(:add_subscriber, %{"status" => status, "detail" => detail}) do
    Logger.warn("Unkown error adding subscriber to MC audience for reason: \"#{detail}\", with status #{status}")
    %{status: :error, type: :mc_unknown, detail: detail}
  end
  defp handle_error(:add_subscriber, {:mc_error_tagging, {sub, error_body}}) do
    Logger.warn("Error tagging parent subscriber \"#{sub.email}\" to MC audience. Error title: #{error_body["title"]}")
    %{status: :error, type: :mc_tagging, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:mc_upsert_error, {sub, error_body}}) do
    Logger.warn("Error upserting subscriber \"#{sub.email}\" to MC audience. Error title: #{error_body["title"]}")
    %{status: :error, type: :mc_upsert, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:local_sub_found, sub}) do
    Logger.warn("Error adding new subscriber \"#{sub.email}\" to our DB, already subscribed.")
    %{status: :error, type: :email_exists, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:local_pending_sub_found, sub}) do
    Logger.warn("Error adding new subscriber \"#{sub.email}\" to our DB, pending email already in DB.")
    %{status: :error, type: :pending_email_exists, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:local_insert_error, {params, chgst = %Ecto.Changeset{}}}) do
    Logger.warn("There was an error inserting new sub \"#{params.email}\" with the following errors: #{Jason.encode!(Keyword.keys(chgst.errors))}")
    %{status: :error, type: :validation, detail: Keyword.keys(chgst.errors)}
  end

  defp respond(conn, status_code, msg) do
    conn
    |> put_status(status_code)
    |> json(msg)
  end

end
