defmodule PlumaApi.MailchimpRepoTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  alias PlumaApi.MailchimpRepo

  @moduledoc """
  REMEMBER TO CLEAR TEST SUBSCRIBERS FROM MAILCHIMP AUDIENCE ONCE DONE
  """

  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  test "MailchimpRepo.check_health/0" do 
    {:ok, %HTTPoison.Response{status_code: 200}} = MailchimpRepo.check_health
  end

  test "MailchimpRepo.check_exists/2" do
    result_true = MailchimpRepo.check_exists("nikokozak@gmail.com", @main_list_id) 
    result_false = MailchimpRepo.check_exists("some_rando@email.com", @main_list_id)

    assert result_true
    refute result_false
  end

  test "MailchimpRepo.add_to_audience/3" do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(PlumaApi.Factory.subscriber())
                        |> Repo.insert

    {:ok, result} = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    assert %HTTPoison.Response{status_code: 200} = result
  end

  test "MailchimpRepo.tag_subscriber/3" do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(PlumaApi.Factory.subscriber())
                        |> Repo.insert

    MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    # !!!!!!!! CAUTION !!!!!!!!!!
    Process.sleep(2000)

    tagged = MailchimpRepo.tag_subscriber(subscriber.email, @main_list_id, [%{name: "Test Tag", status: "active"}])

    assert {:ok, %HTTPoison.Response{status_code: 204}} = tagged
  end

  test "MailchimpRepo.archive_subscriber/2" do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(PlumaApi.Factory.subscriber())
                        |> Repo.insert

    {:ok, _result} = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    Process.sleep(2000)

    {:ok, result} = MailchimpRepo.archive_subscriber(subscriber.email, @main_list_id)

    assert subscriber.email == result
  end

  test "MailchimpRepo.get_subscriber/2" do
    {:ok, result} = MailchimpRepo.get_subscriber("nikokozak@gmail.com", @main_list_id)

    assert result =~ "nikokozak@gmail.com"
  end

  test "MailchimpRepo.update_merge_field/3" do
    {:ok, result} = MailchimpRepo.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => "cookoo"})

    assert %HTTPoison.Response{status_code: 200} = result
   
    {:ok, result} = MailchimpRepo.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => ""})
    
    assert %HTTPoison.Response{status_code: 200} = result
  end

end
