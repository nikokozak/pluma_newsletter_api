defmodule PlumaApi.Mailchimp.RepoTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  use PlumaApi.TestUtils

  @moduletag :mailchimp_tests
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

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.Repo.add_to_list/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, sub} = Subscriber.validate_params(test_sub)
    {:ok, result} = MR.add_to_list(Jason.encode!(sub), @main_list_id)

    email = subscriber.email
    assert %{"email_address" => ^email} = result

    {:ok, sub} = Subscriber.validate_params(test_sub)
    {:error, result} = MR.add_to_list(Jason.encode!(sub), @main_list_id)

    assert %{ "status" => 400 } = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.Repo.tag_subscriber/3", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, test_sub} = Subscriber.validate_params(test_sub)
    {:ok, _result} = MR.add_to_list(Jason.encode!(test_sub), @main_list_id)

    # !!!!!!!! CAUTION !!!!!!!!!!
    Process.sleep(2000)

    assert {:ok, _response} = MR.tag_subscriber(subscriber.email, @main_list_id, [%{name: "Test Tag", status: "active"}])
  end

  test "Mailchimp.Repo.update_merge_field/3" do
    {:ok, result} = MR.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => "cookoo"})

    assert %{"merge_fields" => %{ "PRID" => "cookoo" }} = result
   
    {:ok, result} = MR.update_merge_field("nikokozak@gmail.com", @main_list_id, %{"PRID" => ""})
    
    assert %{"merge_fields" => %{ "PRID" => "" }} = result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.Repo.archive_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, test_sub} = Subscriber.validate_params(test_sub)
    {:ok, _result} = MR.add_to_list(Jason.encode!(test_sub), @main_list_id)

    Process.sleep(2000)

    {:ok, result} = MR.archive_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

  @tag test_sub: PlumaApi.Factory.subscriber()
  test "Mailchimp.Repo.delete_subscriber/2", %{test_sub: test_sub} do
    {:ok, subscriber} = %Subscriber{}
                        |> Subscriber.insert_changeset(test_sub)
                        |> Repo.insert

    {:ok, test_sub} = Subscriber.validate_params(test_sub)
    {:ok, _result} = MR.add_to_list(Jason.encode!(test_sub), @main_list_id)

    Process.sleep(2000)

    {:ok, result} = MR.delete_subscriber(subscriber.email, @main_list_id)

    assert %{} == result
  end

end
