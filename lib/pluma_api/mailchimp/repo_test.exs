defmodule PlumaApi.Mailchimp.RepoTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  use PlumaApi.TestUtils

  @moduletag :mailchimp_repo_tests
  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @moduledoc """
  """

  # In appropriate tests, we add a @tag test_sub: PlumaApi.Factory.subscriber()
  # which becomes available to the testing function via the test context.
  # The subscriber is then deleted via the `on_exit/2` callback
  # This mechanism is handled by the Pluma.TestUtils macro

  test "Mailchimp.Repo.check_health/0" do 
    {:ok, %{"health_status" => _status}} = MR.check_health
  end

  test "Mailchimp.Repo.check_exists/2" do
    result_true = MR.check_exists("nikokozak@gmail.com", @main_list_id) 
    result_false = MR.check_exists("some_rando@email.com", @main_list_id)

    assert result_true
    refute result_false
  end

  test "Mailchimp.Repo.get_subscriber/2" do
    {:ok, result} = MR.get_subscriber("nikokozak@gmail.com", @main_list_id)

    assert %{"email_address" => "nikokozak@gmail.com"} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber(list: @main_list_id)
  test "Mailchimp.Repo.add_to_list/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.changeset(test_sub)
                        |> Ecto.Changeset.apply_action(:insert)

    {:ok, result} = MR.add_to_list(Jason.encode!(subscriber), subscriber.list)

    email = subscriber.email
    assert %{"email_address" => ^email} = result

    # If already present, returns 400
    {:error, result} = MR.add_to_list(Jason.encode!(subscriber), subscriber.list)

    assert %{ "status" => 400 } = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber(list: @main_list_id, status: "pending")
  test "Mailchimp.Repo.upsert_member/3", %{ test_sub: test_sub } do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.changeset(test_sub)
                        |> Ecto.Changeset.apply_action(:insert)

    {:ok, result} = MR.upsert_member(subscriber.email, Jason.encode!(subscriber), subscriber.list)
    assert String.equivalent?(result["status"], "pending")
    Process.sleep(500)

    new_params = %{ subscriber | rid: "anewrid", parent_rid: "anewprid", fname: "Alfredo", status: "unsubscribed" }
    {:ok, _result} = MR.upsert_member(subscriber.email, Jason.encode!(new_params), new_params.list)
    Process.sleep(500)

    {:ok, result} = MR.get_subscriber(new_params.email, new_params.list)
    merge_fields = result["merge_fields"]
    assert String.equivalent?(result["status"], "unsubscribed")
    assert String.equivalent?(merge_fields["FNAME"], "Alfredo")
    assert String.equivalent?(merge_fields["RID"], "anewrid")
    assert String.equivalent?(merge_fields["PRID"], "anewprid")
  end

  test "Mailchimp.Repo.tag_subscriber/3" do
    assert {:ok, sub} = MR.get_subscriber("nikokozak@gmail.com", @main_list_id)
    assert length(sub["tags"]) == 0
    Process.sleep(500)

    assert {:ok, _response} = MR.tag_subscriber("nikokozak@gmail.com", @main_list_id, [%{name: "Test Tag", status: "active"}])
    Process.sleep(500)

    assert {:ok, sub} = MR.get_subscriber("nikokozak@gmail.com", @main_list_id)
    assert length(sub["tags"]) == 1
    Process.sleep(500)

    assert {:ok, _response} = MR.tag_subscriber("nikokozak@gmail.com", @main_list_id, [%{name: "Test Tag", status: "inactive"}])
  end

  test "Mailchimp.Repo.update_merge_field/3" do
    {:ok, result} = MR.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => "cookoo"})

    assert %{"merge_fields" => %{ "PRID" => "cookoo" }} = result
   
    {:ok, result} = MR.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => ""})
    
    assert %{"merge_fields" => %{ "PRID" => "" }} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber(list: @main_list_id)
  test "Mailchimp.Repo.archive_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.changeset(test_sub)
                        |> Ecto.Changeset.apply_action(:insert)

    {:ok, _result} = MR.add_to_list(Jason.encode!(subscriber), @main_list_id)

    Process.sleep(2000)

    {:ok, result} = MR.archive_subscriber(subscriber.email, @main_list_id)
    {:ok, %{"status" => "archived"}} = MR.get_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

  @tag test_sub: PlumaApi.Factory.subscriber(list: @main_list_id)
  test "Mailchimp.Repo.delete_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.changeset(test_sub)
                        |> Ecto.Changeset.apply_action(:insert)

    {:ok, _result} = MR.add_to_list(Jason.encode!(subscriber), @main_list_id)

    Process.sleep(2000)

    {:ok, result} = MR.delete_subscriber(subscriber.email, @main_list_id)
    {:error, _} = MR.get_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

end
