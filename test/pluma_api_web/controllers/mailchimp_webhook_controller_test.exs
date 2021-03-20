defmodule PlumaApiWeb.MailchimpWebhookControllerTest do
  alias PlumaApi.Repo
  alias PlumaApi.Subscriber
  use PlumaApiWeb.ConnCase

  @moduletag :mailchimp_webhook_controller_tests

  test "MailchimpWebhookController.handle_event: subscribe, good data", %{ conn: conn }do
    call = make_subscribe_call(Faker.Internet.email(), Nanoid.generate())

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle_event), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(call["data"]["email"])
      |> Repo.one

    assert not is_nil(subscriber)
    assert subscriber.rid == call["data"]["merges"]["RID"]
  end

  test "MailchimpWebhookController.handle_event: subscribe, sub already in DB", %{ conn: conn }do
    {:ok, subscriber} = Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
                 |> Repo.insert

    call_with_same_email = make_subscribe_call(subscriber.email, Nanoid.generate())

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle_event), call_with_same_email)

    assert json_response(conn, 202) #Respond with a 202, subscriber is present.
  end

  test "MailchimpWebhookController.handle_event: unsubscribe, good data", %{ conn: conn } do
    {:ok, subscriber} = Subscriber.insert_changeset(%Subscriber{}, PlumaApi.Factory.subscriber())
                        |> Repo.insert

    call = make_unsubscribe_call(subscriber.email, subscriber.rid)

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle_event), call)

    assert json_response(conn, 200)

    subscriber =
      Subscriber.with_email(subscriber.email)
      |> Repo.one

    assert is_nil(subscriber)
  end

  test "MailchimpController.handle_event: unsubscribe, no subscriber present", %{ conn: conn } do
    call = make_unsubscribe_call(Faker.Internet.email(), Nanoid.generate())

    conn = post(conn, Routes.mailchimp_webhook_path(conn, :handle_event), call)

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
