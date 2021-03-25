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
                `%NewSubscriber{}` struct for validation. The only *required* attribute
                is a valid-format email.

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
    OK.try do
      validated <- Subscriber.validate_params(params)
      safe <- ensure_doesnt_exist(validated)
      _result <- add_to_mailchimp(safe, @list_id)
    after
      Logger.info("Successfully subscribed #{safe.email}")
      respond(conn, 200, safe)
    rescue
      error -> 
        respond(conn, 400, handle_error(:add_subscriber, error))
    end
  end

  defp ensure_doesnt_exist(subscriber) do
    OK.for do
      _ <- ensure_email_not_in_db(subscriber)
      safe_sub = ensure_no_rid_collision(subscriber)
    after
      safe_sub
    end
  end

  defp add_to_mailchimp(subscriber, list_id) do
    case Mailchimp.add_to_audience(subscriber, list_id) do
      {:ok, body} -> {:ok, body}
      {:error, body} -> {:error, {:mc_add_sub_failure, {subscriber, body}}}
    end
  end

  defp ensure_email_not_in_db(subscriber) do
    Subscriber.with_email(subscriber.email)
    |> Repo.one
    |> case do
      nil -> {:ok, subscriber}
      sub -> {:error, {:local_email_found, sub}}
    end
  end

  defp ensure_no_rid_collision(subscriber) do
    Subscriber.with_rid(subscriber.rid)
    |> Repo.one
    |> case do
      nil -> {:ok, subscriber}
      _sub -> {:ok, assign_new_rid(subscriber)}
    end
  end

  defp assign_new_rid(subscriber), do: %{ subscriber | rid: Nanoid.generate() }
  
  # We consider an existing subscriber error a "pending" error given that we would shortcircuit
  # before if the email was already present in our database, meaning a fully-subscribed user was found.
  defp handle_error(:add_subscriber, {:mc_add_sub_failure, {sub, %{"status" => 400}}}) do
    Logger.warn("Error adding subscriber #{sub.email} to MC audience. Subscriber
      already added, but not present in our local DB, likely waiting on confirmation email.")
    %{status: :error, type: :mc_sub_pending, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:mc_add_sub_failure, {sub, body}}) do
    Logger.warn("Error adding subscriber #{sub.email} to MC audience. Received
      status #{body["status"]} and message \"#{body["title"]}\" from Mailchimp API.")
    %{status: :error, type: :mc_unknown, detail: body["status"]}
  end
  defp handle_error(:add_subscriber, {:local_email_found, sub}) do
    Logger.warn("Error adding new subscriber #{sub.email} to our DB, email already
      in DB.")
    %{status: :error, type: :email_exists, detail: sub.email}
  end
  defp handle_error(:add_subscriber, {:validation, chgst = %Ecto.Changeset{}}) do
    Logger.warn("There was an error validating the following fields: #{Jason.encode!(Keyword.keys(chgst.errors))} for new sub #{chgst.changes.email}")
    %{status: :error, type: :validation, detail: Keyword.keys(chgst.errors)}
  end

  defp respond(conn, status_code, msg) do
    conn
    |> put_status(status_code)
    |> json(msg)
  end

  @doc """
  Unused atm.
  """
  def delete_subscriber(conn, %{"email" => email}) do
    subscriber = 
      Subscriber.with_email(email)
      |> Repo.one

    case Repo.delete(subscriber) do
      {:ok, deleted} ->
        conn
        |> put_status(200)
        |> render("deleted.json", subscriber: deleted)
      {:error, _error} ->
        conn
        |> put_status(400)
        |> put_view(ErrorView)
        |> render("400.json", message: "Could not delete subscriber")
    end
  end

end
