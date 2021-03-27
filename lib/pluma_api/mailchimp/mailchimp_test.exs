defmodule PlumaApi.MailchimpTest do
  alias PlumaApi.Subscriber
  use PlumaApi.DataCase
  alias PlumaApi.Mailchimp
  use PlumaApi.TestUtils

  @moduletag :mailchimp_tests
  @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)
  @moduledoc """
  """

  # In appropriate tests, we add a @tag test_sub: PlumaApi.Factory.subscriber()
  # which becomes available to the testing function via the test context.
  # The subscriber is then deleted via the `on_exit/2` callback
  # This mechanism is handled by the Pluma.TestUtils macro

  describe "Mailchimp.subscribe/1" do

    @tag test_sub: PlumaApi.Factory.subscriber(list: @main_list_id, status: "pending")
    test "Adds a subscriber to a Mailchimp list and the local DB", %{test_sub: test_sub} do
      {:ok, result} = Mailchimp.subscribe(test_sub, @main_list_id)
      merge_fields = result["merge_fields"]

      local_sub = Subscriber.with_email(test_sub.email) |> Repo.one

      refute is_nil(local_sub)
      assert String.equivalent?(result["status"], local_sub.status)
      assert String.equivalent?(merge_fields["RID"], local_sub.rid)
      
      assert Mailchimp.Repo.check_exists(test_sub.email, @main_list_id)
    end

    test "Returns error if validation fails" do
      sub = PlumaApi.Factory.subscriber(email: "notanemail")
      {:error, {:validation, _error}} = Mailchimp.subscribe(sub, @main_list_id)

      sub = PlumaApi.Factory.subscriber(email: "")
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)

      sub = PlumaApi.Factory.subscriber(status: "not_a_status") 
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)
    end

    test "Returns error if subscriber present in local DB" do
      test_sub = PlumaApi.Factory.subscriber()
      {:ok, sub} = Subscriber.changeset(%Subscriber{}, test_sub)
                   |> Repo.insert

      {:error, {:local_email_found, local}} = Mailchimp.subscribe(test_sub, @main_list_id)
      assert String.equivalent?(sub.email, local.email)
    end

    ##TODO: Add batch test_sub tag support in order to test VIP tagging.

  end

  describe "Mailchimp.webhook_subscribe/1" do

    @tag test_sub: PlumaApi.Factory.subscriber(rid: "", status: "subscribed")
    test "Adds a local subscriber", %{test_sub: test_sub} do
      {:ok, mc_result} = Mailchimp.add_to_list(test_sub)

      {:ok, response} = Mailchimp.webhook_subscribe(test_sub)
      merge_fields = response["merge_fields"]

      local_sub = Subscriber.with_email(test_sub.email) |> Repo.one
      refute is_nil(local_sub)
      assert String.length(local_sub.rid) > 4

      assert String.equivalent?(merge_fields["RID"], local_sub.rid)
      assert String.equivalent?(merge_fields["FNAME"], local_sub.fname)
      assert String.equivalent?(response["status"], local_sub.status)
    end

    @tag test_sub: PlumaApi.Factory.subscriber(status: "subscribed")
    test "Updates a local subscriber", %{test_sub: test_sub} do
      {:ok, mc_result} = Mailchimp.add_to_list(test_sub)

      {:ok, local_sub} = Subscriber.changeset(%Subscriber{}, %{ test_sub | status: "pending" })
                         |> PlumaApi.Repo.insert

      {:ok, response} = Mailchimp.webhook_subscribe(test_sub)
      merge_fields = response["merge_fields"]

      assert String.equivalent?(merge_fields["RID"], local_sub.rid)
      assert String.equivalent?(response["status"], "subscribed")
      assert String.equivalent?(response["status"], local_sub.status)
    end

    test "Returns upsert error if params are wrong" do
      sub = PlumaApi.Factory.subscriber(email: "not_an_email")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_subscribe(sub)

      sub = PlumaApi.Factory.subscriber(status: "not_a_status")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_subscribe(sub)

      sub = PlumaApi.Factory.subscriber(email: "")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_subscribe(sub)
    end

  end

  describe "Mailchimp.webhook_unsubscribe/1" do

    test "Updates local status to 'unsubscribed'" do
      test_sub = PlumaApi.Factory.subscriber(status: "subscribed")
      {:ok, local_sub} = Subscriber.changeset(%Subscriber{}, test_sub)
                         |> PlumaApi.Repo.insert

      {:ok, _} = Mailchimp.webhook_unsubcribe(%{ test_sub | status: "unsubscribed" })

      local_sub = Subscriber.with_email(test_sub.email) |> Repo.one
      refute is_nil(local_sub)
      assert String.equivalent?(local_sub.status, "unsubscribed")
    end

    test "Returns upsert error if params are wrong" do
      sub = PlumaApi.Factory.subscriber(email: "not_an_email")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_unsubscribe(sub)

      sub = PlumaApi.Factory.subscriber(status: "not_a_status")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_unsubscribe(sub)

      sub = PlumaApi.Factory.subscriber(email: "")
      {:error, {:local_upsert_error, _error}} = Mailchimp.webhook_unsubscribe(sub)
    end

  end

end
