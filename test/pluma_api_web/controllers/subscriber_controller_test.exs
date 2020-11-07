defmodule PlumaApiWeb.SubscriberControllerTest do
  use PlumaApiWeb.ConnCase
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo

  test "retrieves subscriber details from DB", %{conn: conn} do
    {:ok, subscriber} =
        Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
        |> Repo.insert

    conn = get(conn, Routes.subscriber_path(conn, :subscriber_details), %{email: subscriber.email})

    assert json_response(conn, 200)
    assert conn.resp_body =~ subscriber.email
  end

end
