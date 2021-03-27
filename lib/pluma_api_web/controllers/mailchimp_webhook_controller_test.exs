defmodule PlumaApiWeb.MailchimpWebhookControllerTest do
  alias PlumaApi.Repo
  alias PlumaApi.Subscriber
  alias PlumaApi.Mailchimp
  use PlumaApiWeb.ConnCase
  use PlumaApi.TestUtils

  @moduletag :mailchimp_webhook_controller_tests
  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  # In appropriate tests, we add a @tag test_sub: PlumaApi.Factory.subscriber()
  # which becomes available to the testing function via the test context.
  # The subscriber is then deleted via the `on_exit/2` callback
  # This mechanism is handled by the Pluma.TestUtils macro

  # Subscriber local is "pending", remote confirmation of subscription arrives.
  # Assumes Mailchimp.subscribe flow previous to this event. (i.e. local added, remote added, both pending)
  @tag test_sub: PlumaApi.Factory.subscriber(status: "pending")
  test "MailchimpWebhookController.handle: subscribe, good data", %{ conn: conn, test_sub: test_sub }do
    {:ok, sub} = Subscriber.changeset(%Subscriber{}, test_sub)
                 |> Repo.insert

    {:ok, response} = Mailchimp.add_to_list(%{ sub | status: "subscribed" })

    call = PlumaApi.Factory.subscribe_webhook(test_sub.email, test_sub)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(test_sub.email)
      |> Repo.one

    assert subscriber.status == "subscribed"
  end

  #If an external subscriber is received, and does not include an RID, said subscriber should
  #be added to our DB and an RID given to our local and remote subscribers.
  @tag test_sub: PlumaApi.Factory.subscriber(rid: "", status: "subscribed")
  test "MailchimpWebhookController.handle: subscribe, missing RID", %{ conn: conn, test_sub: test_sub }do
    {:ok, sub} = Subscriber.changeset(%Subscriber{}, test_sub)
                 |> Ecto.Changeset.apply_action(:insert)

    {:ok, response} = Mailchimp.add_to_list(%{ sub | status: "subscribed", rid: "" })
    assert String.equivalent?(response["merge_fields"]["RID"], "") 

    call = PlumaApi.Factory.subscribe_webhook(test_sub.email, test_sub)
    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(test_sub.email)
      |> Repo.one

    assert not is_nil(subscriber)
    assert String.length(subscriber.rid) > 0 

    {:ok, remote_sub} = Mailchimp.Repo.get_subscriber(test_sub.email, @list_id)

    assert String.equivalent?(remote_sub["merge_fields"]["RID"], subscriber.rid)
  end

  # Update "status" to unsubscribed
  test "MailchimpWebhookController.handle: unsubscribe, good data", %{ conn: conn } do
    test_sub = PlumaApi.Factory.subscriber(status: "subscribed")
    {:ok, subscriber} = Subscriber.changeset(%Subscriber{}, test_sub)
                        |> Repo.insert

    call = PlumaApi.Factory.unsubscribe_webhook(subscriber.email, test_sub)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 204)

    subscriber =
      Subscriber.with_email(subscriber.email)
      |> Repo.one

    assert String.equivalent?(subscriber.status, "unsubscribed")
  end

  defp make_unsubscribe_call(email, rid, parent_rid \\ "") do
    %{
      "type" => "unsubscribe",
      "fired_at" => Date.utc_today,
      "data" => %{
        "action" => "unsub",
        "reason" => "manual",
        "id" => Nanoid.generate(10),
        "email" => email,
        "email_type" => "html",
        "ip_opt" => Faker.Internet.ip_v4_address(),
        "web_id" => Nanoid.generate(10),
        "merges" => %{
          "EMAIL" => email,
          "FNAME" => Faker.Person.first_name(),
          "LNAME" => Faker.Person.last_name(),
          "ADDRESS" => "",
          "PHONE" => "",
          "BIRTHDAY" => "",
          "RID" => rid,
          "PRID" => parent_rid
        }
      },
      "list_id" => "4cc41938a8"
    }
  end

end
