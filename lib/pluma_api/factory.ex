defmodule PlumaApi.Factory do
  @main_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list)

  def subscriber(opts \\ []) do
    %{
      mchimp_id: getopt(opts, :mchimp_id) || Nanoid.generate(),
      email: getopt(opts, :email) || Faker.Internet.email,
      list: getopt(opts, :list) || @main_list, 
      rid: getopt(opts, :rid) || Nanoid.generate(),
      parent_rid: getopt(opts, :parent_rid) || "",
      fname: getopt(opts, :fname) || "",
      lname: getopt(opts, :lname) || "",
      status: getopt(opts, :status) || "subscribed",
      tags: getopt(opts, :tags) || ["Test"],
      ip_signup: getopt(opts, :ip_signup) || Faker.Internet.ip_v4_address(),
      country: getopt(opts, :country) || ""
    }
  end

  def subscribe_webhook(email, opts) do
    %{
      "type" => "subscribe",
      "fired_at" => Date.utc_today,
      "data" => %{
        "id" => Nanoid.generate(10),
        "email" => email,
        "email_type" => "html",
        "ip_opt" => getopt(opts, :ip_signup) || Faker.Internet.ip_v4_address(),
        "ip_signup" => getopt(opts, :ip_signup) || Faker.Internet.ip_v4_address(),
        "web_id" => Nanoid.generate(10),
        "merges" => %{
          "EMAIL" => email,
          "FNAME" => getopt(opts, :fname) || Faker.Person.first_name(),
          "LNAME" => getopt(opts, :lname) || Faker.Person.last_name(),
          "ADDRESS" => "",
          "PHONE" => "",
          "BIRTHDAY" => "",
          "RID" => getopt(opts, :rid) || "",
          "PRID" => getopt(opts, :parent_rid) || ""
        }
      },
      "list_id" => getopt(opts, :list) || @main_list
    }
  end

  def unsubscribe_webhook(email, opts) do
    %{
      "type" => "unsubscribe",
      "fired_at" => Date.utc_today,
      "data" => %{
        "action" => "unsub",
        "reason" => "manual",
        "id" => Nanoid.generate(10),
        "email" => email,
        "email_type" => "html",
        "ip_opt" => getopt(opts, :ip_signup) || Faker.Internet.ip_v4_address(),
        "web_id" => Nanoid.generate(10),
        "merges" => %{
          "EMAIL" => email,
          "FNAME" => getopt(opts, :fname) || Faker.Person.first_name(),
          "LNAME" => getopt(opts, :lname) || Faker.Person.last_name(),
          "ADDRESS" => "",
          "PHONE" => "",
          "BIRTHDAY" => "",
          "RID" => getopt(opts, :rid) || "",
          "PRID" => getopt(opts, :parent_rid) || ""
        }
      },
      "list_id" => getopt(opts, :list) || @main_list
    }
  end

  defp getopt(opts, key), do: Keyword.get(opts, key)

end
