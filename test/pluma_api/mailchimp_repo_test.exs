defmodule PlumaApi.MailchimpRepoTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  alias PlumaApi.MailchimpRepo
  use PlumaApi.TestUtils

  @moduletag :mailchimp_repo_tests
  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @moduledoc """
  """

  # In appropriate tests, we add a @tag push_sub: PlumaApi.Factory.subscriber()
  # which becomes available to the testing function via the test context.
  # The subscriber is then deleted via the `on_exit/2` callback
  # setup :remove_test_subs_from_mailchimp

  test "MailchimpRepo.check_health/0" do 
    {:ok, %HTTPoison.Response{status_code: 200}} = MailchimpRepo.check_health
  end

  test "MailchimpRepo.check_exists/2" do
    result_true = MailchimpRepo.check_exists("nikokozak@gmail.com", @main_list_id) 
    result_false = MailchimpRepo.check_exists("some_rando@email.com", @main_list_id)

    assert result_true
    refute result_false
  end

  test "MailchimpRepo.get_subscriber/2" do
    {:ok, result} = MailchimpRepo.get_subscriber("nikokozak@gmail.com", @main_list_id)

    assert result =~ "nikokozak@gmail.com"
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpRepo.add_to_audience/3", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, result} = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    assert %HTTPoison.Response{status_code: 200} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpRepo.tag_subscriber/3", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    # !!!!!!!! CAUTION !!!!!!!!!!
    Process.sleep(2000)

    tagged = MailchimpRepo.tag_subscriber(subscriber.email, @main_list_id, [%{name: "Test Tag", status: "active"}])

    assert {:ok, %HTTPoison.Response{status_code: 204}} = tagged
  end

  test "MailchimpRepo.update_merge_field/3" do
    {:ok, result} = MailchimpRepo.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => "cookoo"})

    assert %HTTPoison.Response{status_code: 200} = result
   
    {:ok, result} = MailchimpRepo.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => ""})
    
    assert %HTTPoison.Response{status_code: 200} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpRepo.archive_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, _result} = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    Process.sleep(2000)

    {:ok, result} = MailchimpRepo.archive_subscriber(subscriber.email, @main_list_id)

    assert subscriber.email == result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "MailchimpRepo.delete_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, _result} = MailchimpRepo.add_to_audience(subscriber, @main_list_id, true)

    Process.sleep(2000)

    {:ok, result} = MailchimpRepo.delete_subscriber(subscriber.email, @main_list_id)

    assert subscriber.email == result
  end

  # In case we want to pass a [list or single] of test subscribers to test
  defp concat(a, b) when is_list(a) and is_list(b), do: a ++ b
  defp concat(a, b) when is_list(b), do: [a] ++ b
  defp concat(a, b) when is_list(a), do: a ++ [b]

end
