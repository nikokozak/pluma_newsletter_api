defmodule PlumaApiWeb.SubscriberControllerTest do
  use PlumaApiWeb.ConnCase
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo

  @moduletag :subscriber_controller_tests


  # Tests both ?rid and ?email params
  test "get_subscriber/2", %{conn: conn} do
    {:ok, subscriber} =
        Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
        |> Repo.insert

    conn_email = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{email: subscriber.email})
    conn_rid = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{rid: subscriber.rid})

    assert json_response(conn_email, 200)
    assert json_response(conn_rid, 200)

    assert conn_email.resp_body =~ subscriber.email
    assert conn_rid.resp_body =~ subscriber.email

    conn_email_failure = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{email: "nonexistent@email.com"})
    conn_rid_failure = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{rid: "111111111"})

    assert json_response(conn_email_failure, 404)
    assert json_response(conn_email_failure, 404)

    assert Jason.decode!(conn_email_failure.resp_body) == %{ "errors" => %{ "detail" => "Could not find subscriber" } }
    assert Jason.decode!(conn_rid_failure.resp_body) == %{ "errors" => %{ "detail" => "Could not find subscriber" } }
  end

  test "new_subscriber/2", %{conn: conn} do

  end



  defp make_new_subscriber_call(prid \\ "") do
    %{
      "fname" => Faker.Person.En.first_name(),
      "lname" => Faker.Person.En.last_name(),
      "email" => Faker.Internet.email(),
      "rid" => Nanoid.generate(10),
      "prid" => prid,
      "ip_signup" => Faker.Internet.ip_v4_address()
    }
  end

end
