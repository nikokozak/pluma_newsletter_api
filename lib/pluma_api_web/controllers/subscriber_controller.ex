defmodule PlumaApiWeb.SubscriberController do
  require Logger
  use PlumaApiWeb, :controller  
  alias PlumaApiWeb.ErrorView
  alias PlumaApi.{Subscriber, Repo}

  def get_subscriber(conn, _params = %{"email" => email}) do
    subscriber_query = Subscriber.with_email(email)
                 |> Subscriber.preload_referees
    
    handle_get_subscriber(conn, subscriber_query)
  end

  def get_subscriber(conn, _params = %{"rid" => rid}) do
    subscriber_query = Subscriber.with_rid(rid)
                 |> Subscriber.preload_referees()

    handle_get_subscriber(conn, subscriber_query)
  end

  defp handle_get_subscriber(conn, subscriber_query) do
    case Repo.one(subscriber_query) do
      nil ->
        conn
        |> put_status(404)
        |> put_view(ErrorView)
        |> render("404.json", message: "Could not find subscriber")
      sub ->
        conn
        |> put_status(200)
        |> render("details.json", subscriber: sub)
    end
  end

  def new_subscriber(conn, params = %{"email" => email}) do
    Logger.info("Received new subscription request for #{email}")
    params
    |> validate_fields
    |> check_exists
    |> add_to_mc_list
    |> respond_to_request(conn)
  end

  # TODO: Add validation for ip_signup
  defp validate_fields(form_data = %{"email" => email, "fname" => fname, "lname" => lname, "rid" => rid, "prid" => prid}) do
    with {:email, true} <- is_valid?(:email, email),
         {:fname, true} <- is_valid?(:fname, fname),
         {:lname, true} <- is_valid?(:lname, lname),
         {:rid, true} <- is_valid?(:rid, rid),
         {:prid, true} <- is_valid?(:prid, prid)
    do
      Logger.info("All fields for #{email} are sanitized")
      %{status: :ok, data: form_data, stage: :sanitize}
    else
      {field, false} -> 
        Logger.warn("There was an error sanitizing field #{field}")
        %{status: :error, detail: field, stage: :sanitize}
    end
  end

  defp is_valid?(field_type, field_data), do: {field_type, String.match?(field_data, reg(field_type))}

  defp reg(type) when is_atom(type) do
    case type do
      :email -> ~r/^[^@\s]+@[^@\s]+\.[^@\s]+$/
      :fname -> ~r/^[\w\s]*$/
      :lname -> ~r/^[\w\s]*$/
      :rid -> ~r/^[\w_-]*$/ 
      :prid -> ~r/^[\w_-]*$/
    end
  end

  defp check_exists(msg = %{status: :error}), do: msg
  defp check_exists(%{status: :ok, data: form_data}) do
    sub = Subscriber.with_email(form_data["email"]) |> Repo.one
    rid = Subscriber.with_rid(form_data["rid"]) |> Repo.one
    
    case {is_nil(sub), is_nil(rid)} do
      {true, true} -> 
        Logger.info("No trace of new subscriber #{form_data["email"]} found in DB")
        %{status: :ok, data: form_data, stage: :check_exists}
      {true, false} ->
        Logger.warn("RID entry for #{form_data["email"]} found in DB: #{form_data["rid"]}")
        Logger.warn("Adding new RID to form_data for #{form_data["email"]}")
        form_data = Map.put(form_data, "rid", "#{Nanoid.generate(10)}")
        %{status: :ok, data: form_data, stage: :check_exists}
      {_x, _y} -> 
        Logger.warn("RID and Email entry for #{form_data["email"]} found in DB")
        %{status: :error, detail: "email_exists", stage: :check_exists}
    end
  end

  defp add_to_mc_list(msg = %{status: :error}), do: msg
  defp add_to_mc_list(%{status: :ok, data: form_data}) do
    case PlumaApi.MailchimpRepo.add_to_mc_audience(form_data, Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)) do
      {:ok, _response} ->
        Logger.info("Successfully added new subscriber #{form_data["email"]} to our Mailchimp List")
        %{status: :ok, detail: :success, stage: :mc}
      {:error, %{"status" => 400}} ->
        Logger.info("Subscriber already added, waiting on email-confirmation for #{form_data["email"]}")
        %{status: :error, detail: "pending", stage: :mc}
      {:error, %{"status" => status_code, "title" => body}} -> 
        Logger.warn("There was an error adding new subscriber #{form_data["email"]} to our Mailchimp List.")
        Logger.warn("Received a response with code #{status_code} and body #{body}")
        %{status: :error, detail: %{ body: body, status_code: status_code}, stage: :mc}  
      _other -> 
        Logger.warn("There was an unhandled error adding new subscriber #{form_data["email"]} to our Mailchimp List.")
        %{status: :error, detail: "There was an unhandled error when interfacing with Mailchimp", stage: :mc}
    end
  end

  defp respond_to_request(msg = %{status: :error}, conn) do
    conn
    |> put_status(400)
    |> json(msg)
  end
  defp respond_to_request(msg = %{status: :ok}, conn) do
    conn
    |> put_status(200)
    |> json(msg)
  end

  def delete(conn, %{"email" => email}) do
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
