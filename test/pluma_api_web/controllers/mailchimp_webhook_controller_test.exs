defmodule PlumaApiWeb.MailchimpWebhookControllerTest do
  alias PlumaApi.Repo
  alias PlumaApi.Subscriber
  use PlumaApiWeb.ConnCase
  use PlumaApi.TestUtils

  @moduletag :mailchimp_webhook_controller_tests
  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  #If an external subscriber is received, and includes an RID, said subscriber should
  #be added to our DB.
  test "MailchimpWebhookController.handle: subscribe, good data", %{ conn: conn }do
    call = make_subscribe_call(Faker.Internet.email(), Nanoid.generate())

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(call["data"]["email"])
      |> Repo.one

    assert not is_nil(subscriber)
    assert subscriber.rid == call["data"]["merges"]["RID"]
  end

  #If an external subscriber is received, and does not include an RID, said subscriber should
  #be added to our DB and an RID given to our local and remote subscribers.
  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpWebhookController.handle: subscribe, missing RID", %{ conn: conn, test_sub: test_sub }do
    {:ok, _resp} = Mailchimp.add_to_audience(%Subscriber{
      email: test_sub.email,
      rid: "",
      parent_rid: "",
      list: test_sub.list}, 
    @list_id, true)

    call = make_subscribe_call(test_sub.email, "")

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(call["data"]["email"])
      |> Repo.one

    assert not is_nil(subscriber)
    assert String.length(subscriber.rid) > 5 

    {:ok, remote_sub} = Mailchimp.get_subscriber(test_sub.email, @list_id)

    assert String.equivalent?(remote_sub["merge_fields"]["RID"], subscriber.rid)
  end

  #If the subscriber is already in our DB, and both external and local have same RID's
  #nothing should happen.
  test "MailchimpWebhookController.handle: subscribe, sub already in DB", %{ conn: conn }do
    {:ok, subscriber} = Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
                 |> Repo.insert

    call_with_same_email = make_subscribe_call(subscriber.email, subscriber.rid)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call_with_same_email)

    assert json_response(conn, 200) #Respond with a 200, subscriber is present.
  end

  #If a subscriber is received from Mailchimp, and is already present in our DB with a different
  #RID, then update the external subscriber's RID.
  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpWebhookController.handle: subscribe, sub already in DB, different RIDs", %{ conn: conn, test_sub: test_sub }do
    remote_rid = Nanoid.generate()

    {:ok, _resp} = Mailchimp.add_to_audience(%Subscriber{
      email: test_sub.email,
      rid: remote_rid,
      parent_rid: test_sub.parent_rid,
      list: test_sub.list}, 
    @list_id, true)

    {:ok, subscriber} = Subscriber.insert_changeset(%Subscriber{}, test_sub)
                 |> Repo.insert

    call_with_same_email = make_subscribe_call(subscriber.email, remote_rid)

    Process.sleep(1000)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call_with_same_email)

    assert json_response(conn, 200)

    {:ok, sub} = Mailchimp.get_subscriber(test_sub.email, @list_id)

    assert sub["merge_fields"]["RID"] == subscriber.rid
  end

  # Simply delete the subscriber if call is correct.
  test "MailchimpWebhookController.handle: unsubscribe, good data", %{ conn: conn } do
    {:ok, subscriber} = Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
                        |> Repo.insert

    call = make_unsubscribe_call(subscriber.email, subscriber.rid)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 204)

    subscriber =
      Subscriber.with_email(subscriber.email)
      |> Repo.one

    assert is_nil(subscriber)
  end

  # Don't do anything, return 202 if call is incorrect.
  test "MailchimpController.handle: unsubscribe, no subscriber present", %{ conn: conn } do
    call = make_unsubscribe_call(Faker.Internet.email(), Nanoid.generate())

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle), call)

    assert json_response(conn, 202)
  end

  defp make_subscribe_call(email, rid, parent_rid \\ "") do
    %{
      "type" => "subscribe",
      "fired_at" => Date.utc_today,
      "data" => %{
        "id" => Nanoid.generate(10),
        "email" => email,
        "email_type" => "html",
        "ip_opt" => Faker.Internet.ip_v4_address(),
        "ip_signup" => Faker.Internet.ip_v4_address(),
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
