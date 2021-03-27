defmodule PlumaApiWeb.SubscriberControllerTest do
  use PlumaApiWeb.ConnCase
  use PlumaApi.TestUtils
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo

  @moduletag :subscriber_controller_tests
  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  describe "SubscriberController.get_subscriber/2" do

    test "gets subscriber with valid RID or Email", %{conn: conn} do
      {:ok, subscriber} =
          Subscriber.changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
          |> Repo.insert

      conn_email = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{email: subscriber.email})
      conn_rid = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{rid: subscriber.rid})

      assert json_response(conn_email, 200)
      assert json_response(conn_rid, 200)

      assert conn_email.resp_body =~ subscriber.email
      assert conn_rid.resp_body =~ subscriber.email
    end

    test "returns 404 on incorrect param or no subscriber", %{conn: conn} do
      conn_email_failure = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{email: "nonexistent@email.com"})
      conn_rid_failure = get(conn, Routes.subscriber_path(conn, :get_subscriber), %{rid: "111111111"})

      assert json_response(conn_email_failure, 404)
      assert json_response(conn_email_failure, 404)

      assert Jason.decode!(conn_email_failure.resp_body) == %{ "errors" => %{ "detail" => "Could not find subscriber" } }
      assert Jason.decode!(conn_rid_failure.resp_body) == %{ "errors" => %{ "detail" => "Could not find subscriber" } }
    end

  end

  describe "add_subscriber/2" do

    @tag test_sub: PlumaApi.Factory.subscriber(status: "pending")
    test "adds a local and remote 'pending' subscriber and returns 200", %{conn: conn, test_sub: test_sub} do
      conn_new = post(conn, Routes.subscriber_path(conn, :add_subscriber), make_new_subscriber_call(test_sub))

      assert json_response(conn_new, 200)

      local_sub = Subscriber.with_email(test_sub.email) |> Repo.one
      refute is_nil(local_sub)
      assert String.equivalent?(local_sub.status, "pending")

      {:ok, remote_sub} = PlumaApi.Mailchimp.Repo.get_subscriber(test_sub.email, test_sub.list)
      assert String.equivalent?(remote_sub["status"], "pending")
        
      assert String.equivalent?(local_sub.rid, remote_sub["merge_fields"]["RID"])
    end

    test "returns an insert error along with validation errors on wrong params", %{conn: conn} do
      test_sub = PlumaApi.Factory.subscriber(email: "not_an_email")
      conn_invalid = post(conn, Routes.subscriber_path(conn, :add_subscriber), make_new_subscriber_call(test_sub))

      assert json_response(conn_invalid, 400)
      assert %{"status" => "error", "type" => "validation", "detail" => _errors} = Jason.decode!(conn_invalid.resp_body)
    end

    test "returns an error along with subscriber details if a pending sub already exists", %{conn: conn} do
      test_sub = PlumaApi.Factory.subscriber(status: "pending")
      {:ok, _pending_sub} = Subscriber.changeset(%Subscriber{}, test_sub) 
                           |> Repo.insert

      conn_pending = post(conn, Routes.subscriber_path(conn, :add_subscriber), make_new_subscriber_call(test_sub))

      assert json_response(conn_pending, 400)
      assert %{"status" => "error",
        "type" => "pending_email_exists",
        "detail" => _email} = Jason.decode!(conn_pending.resp_body)
    end

    @tag test_sub: PlumaApi.Factory.subscriber(status: "subscribed")
    test "returns an error along with subscriber details if subscribed sub already exists", %{conn: conn, test_sub: test_sub} do
      {:ok, _sub} = Subscriber.changeset(%Subscriber{}, test_sub)
                   |> Repo.insert
      conn_existing = post(conn, Routes.subscriber_path(conn, :add_subscriber), make_new_subscriber_call(test_sub))

      assert json_response(conn_existing, 400)
      assert %{"status" => "error", 
        "type" => "email_exists",
        "detail" => _} = Jason.decode!(conn_existing.resp_body)
    end
  end

  defp make_new_subscriber_call(factory_sub) when is_map(factory_sub) do
    %{
      "fname" => factory_sub.fname,
      "lname" => factory_sub.lname,
      "email" => factory_sub.email,
      "rid" => factory_sub.rid,
      "prid" => factory_sub.parent_rid,
      "ip_signup" => factory_sub.ip_signup
    }
  end

end
