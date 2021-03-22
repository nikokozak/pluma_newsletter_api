defmodule PlumaApi.MailchimpTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  alias PlumaApi.Mailchimp
  use PlumaApi.TestUtils

  @moduletag :mailchimp_repo_tests
  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @moduledoc """
  """

  # In appropriate tests, we add a @tag push_sub: PlumaApi.Factory.subscriber()
  # which becomes available to the testing function via the test context.
  # The subscriber is then deleted via the `on_exit/2` callback
  # setup :remove_test_subs_from_mailchimp

  test "Mailchimp.check_health/0" do 
    {:ok, %{"health_status" => _status}} = Mailchimp.check_health
  end

  test "Mailchimp.check_exists/2" do
    result_true = Mailchimp.check_exists("nikokozak@gmail.com", @main_list_id) 
    result_false = Mailchimp.check_exists("some_rando@email.com", @main_list_id)

    assert result_true
    refute result_false
  end

  test "Mailchimp.get_subscriber/2" do
    {:ok, result} = Mailchimp.get_subscriber("nikokozak@gmail.com", @main_list_id)

    assert %{"email_address" => "nikokozak@gmail.com"} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.add_to_audience/3", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, result} = Mailchimp.add_to_audience(subscriber, @main_list_id, true)

    email = subscriber.email
    assert %{"email_address" => ^email} = result

    {:error, result} = Mailchimp.add_to_audience(subscriber, @main_list_id, true)

    assert %{ "status" => 400 } = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.tag_subscriber/3", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, _response} = Mailchimp.add_to_audience(subscriber, @main_list_id, true)

    # !!!!!!!! CAUTION !!!!!!!!!!
    Process.sleep(2000)

    assert {:ok, _response} = Mailchimp.tag_subscriber(subscriber.email, @main_list_id, [%{name: "Test Tag", status: "active"}])
  end

  test "Mailchimp.update_merge_field/3" do
    {:ok, result} = Mailchimp.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => "cookoo"})

    assert %{"merge_fields" => %{ "PRID" => "cookoo" }} = result
   
    {:ok, result} = Mailchimp.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => ""})
    
    assert %{"merge_fields" => %{ "PRID" => "" }} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.archive_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, _result} = Mailchimp.add_to_audience(subscriber, @main_list_id, true)

    Process.sleep(2000)

    {:ok, result} = Mailchimp.archive_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.delete_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, _result} = Mailchimp.add_to_audience(subscriber, @main_list_id, true)

    Process.sleep(2000)

    {:ok, result} = Mailchimp.delete_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

end
