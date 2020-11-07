defmodule PlumaApiWeb.MailchimpControllerTest do
  alias PlumaApi.Repo
  alias PlumaApi.Subscriber
  use PlumaApiWeb.ConnCase

  test "accepts subscribe webhook, adds subscriber to DB", %{ conn: conn }do
    call = make_subscribe_call(Faker.Internet.email(), Nanoid.generate())

    conn = post(conn, Routes.mailchimp_path(conn, :handle_event), call)

    assert json_response(conn, 200)

    subscriber = 
      Subscriber.with_email(call["data"]["email"])
      |> Repo.one

    assert not is_nil(subscriber)
    assert subscriber.rid == call["data"]["merges"]["RID"]
  end

  test "accepts unsubscribe webhook, removes subscriber from DB", %{ conn: conn } do
    {:ok, subscriber} =
      Subscriber.insert_changeset(%Subscriber{}, %{
        email: Faker.Internet.email,
        rid: Nanoid.generate(),
        mchimp_id: Nanoid.generate(),
        list: "4cc41938a8"
      }) |> Repo.insert

    call = make_unsubscribe_call(subscriber.email, subscriber.rid)

    conn = post(conn, Routes.mailchimp_path(conn, :handle_event), call)

    assert json_response(conn, 200)

    subscriber =
      Subscriber.with_email(subscriber.email)
      |> Repo.one

    assert is_nil(subscriber)
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
