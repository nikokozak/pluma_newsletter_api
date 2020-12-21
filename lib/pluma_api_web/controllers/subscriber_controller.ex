defmodule PlumaApiWeb.SubscriberController do
  use PlumaApiWeb, :controller  
  alias PlumaApiWeb.ErrorView
  alias PlumaApi.{Subscriber, Repo}

  def subscriber_details(conn, _params = %{"email" => email}) do
    subscriber_query = Subscriber.with_email(email)
                 |> Subscriber.preload_referees
    
    handle_get_subscriber(conn, subscriber_query)
  end

  def subscriber_details(conn, _params = %{"id" => id}) do
    subscriber_query = Subscriber.with_id(id)
                 |> Subscriber.preload_referees

    handle_get_subscriber(conn, subscriber_query)
  end

  def subscriber_details(conn, _params = %{"rid" => rid}) do
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
