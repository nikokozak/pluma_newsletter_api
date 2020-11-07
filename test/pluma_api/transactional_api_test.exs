defmodule PlumaApi.TransactionalAPITest do
  use PlumaApi.DataCase
  alias PlumaApi.TransactionalAPI
  alias PlumaApi.MailchimpRepo
  alias PlumaApi.MailosaurAPI

  @tag :skip
  test "pings transactional api" do
    result = TransactionalAPI.check_health()
    {:ok, %HTTPoison.Response{status_code: 200}} = result
  end

  @tag :skip
  test "sends a message (check in mailosaur)" do

    random_recipient = MailchimpRepo.generate_testing_email()
    message = 
      TransactionalAPI.make_message(
        "niko@pluma.cc",
        random_recipient,
        "First test",
        "Some body text here"
      )

    {:ok, result} = TransactionalAPI.send_email(message)
    %HTTPoison.Response{status_code: 200} = result

    # !!!!!!!!      CAUTION      !!!!!!!!!!
    Process.sleep(5000)

    {:ok, result} = MailosaurAPI.find_message(%{sentTo: random_recipient, match: "ALL"})
    {:ok, %{"items" => items}} = Jason.decode(result.body)

    assert length(items) == 1

  end

  @tag :skip
  test "sends a welcome email (check in mailosaur)" do

    random_recipient = MailchimpRepo.generate_testing_email()
    {:ok, %HTTPoison.Response{status_code: 200}} = TransactionalAPI.send_welcome_email(random_recipient)

    # !!!!!!!!      CAUTION      !!!!!!!!!!
    Process.sleep(5000)

    {:ok, result} = MailosaurAPI.find_message(%{sentTo: random_recipient, match: "ALL"})
    {:ok, %{"items" => items}} = Jason.decode(result.body)

    assert length(items) == 1
  end
  
end
