defmodule PlumaApi.MailchimpRepoTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase

  alias PlumaApi.MailchimpRepo

  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  test "pings mailchimp api" do 
    {:ok, %HTTPoison.Response{status_code: 200}} = MailchimpRepo.check_health
  end

  test "check if subscriber exists in main list" do
    result_true = MailchimpRepo.check_exists("nikokozak@gmail.com", @main_list_id) 
    result_false = MailchimpRepo.check_exists("some_rando@email.com", @main_list_id)

    assert result_true
    refute result_false
  end

  test "tags a subscriber" do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(PlumaApi.Factory.subscriber())
                        |> Repo.insert

    result = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    # !!!!!!!! CAUTION !!!!!!!!!!
    Process.sleep(3000)

    tagged = MailchimpRepo.tag_subscriber(subscriber.email, @main_list_id, [%{name: "Test Tag", status: "active"}])

    assert {:ok, %HTTPoison.Response{status_code: 204}} = tagged
  end

end
