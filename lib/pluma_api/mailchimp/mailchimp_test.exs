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

  describe "Mailchimp.add_to_list/2" do

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Adds a subscriber to a Mailchimp list", %{test_sub: test_sub} do
      {:ok, result} = Mailchimp.add_to_list(test_sub, @main_list_id)

      email = test_sub.email
      assert %{"email_address" => ^email} = result
    end

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Returns an error if subscriber already present in Mailchimp list", %{test_sub: test_sub} do
      {:ok, result} = Mailchimp.add_to_list(test_sub, @main_list_id)

      email = test_sub.email
      assert %{"email_address" => ^email} = result

      {:error, result} = Mailchimp.add_to_list(test_sub, @main_list_id)

      assert %{"status" => 400} = result
    end

    test "Returns a validation error if parameters are incorrect" do
      sub = %{ PlumaApi.Factory.subscriber() | email: "not_an_email" }
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | status: "not_a_status" }
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | email: "" }
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)
    end

  end

  describe "Mailchimp.subscribe/2" do

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Adds a subscriber to a Mailchimp list", %{test_sub: test_sub} do
      {:ok, _result} = Mailchimp.subscribe(test_sub, @main_list_id)
      
      assert Mailchimp.Repo.check_exists(test_sub.email, @main_list_id)
    end

    test "Returns error if validation fails" do
      sub = %{ PlumaApi.Factory.subscriber() | email: "not_an_email" }
      {:error, {:validation, _error}} = Mailchimp.subscribe(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | status: "not_a_status" }
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | email: "" }
      {:error, {:validation, _error}} = Mailchimp.add_to_list(sub, @main_list_id)
    end

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Returns error if subscriber present in local DB", %{test_sub: test_sub} do
      {:ok, sub} = Subscriber.insert_changeset(%Subscriber{}, test_sub)
                   |> Repo.insert

      {:error, {:local_email_found, local}} = Mailchimp.subscribe(test_sub, @main_list_id)
      assert String.equivalent?(sub.email, local.email)
    end

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Creates new RID if collision with local RID exists", %{test_sub: test_sub} do
      rid = Nanoid.generate()
      {:ok, sub} = Subscriber.insert_changeset(%Subscriber{}, %{email: "atest@gmail.com", rid: rid})
                   |> Repo.insert

      {:ok, response} = Mailchimp.subscribe(%{ test_sub | rid: rid }, @main_list_id)
      refute String.equivalent?(sub.rid, response["merge_fields"]["RID"])
    end

  end

  describe "Mailchimp.confirm_subscription/2" do

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Adds a local subscriber", %{test_sub: test_sub} do
      {:ok, mc_result} = Mailchimp.add_to_list(test_sub, @main_list_id)

      {:ok, local_result} = Mailchimp.confirm_subscription(test_sub, @main_list_id)

      assert String.equivalent?(local_result.email, test_sub.email)
      assert String.equivalent?(local_result.rid, mc_result["merge_fields"]["RID"])
    end

    @tag test_sub: PlumaApi.Factory.subscriber()
    test "Syncs RID's with bias to local RID", %{test_sub: test_sub} do
      remote_rid = Nanoid.generate()
      local_rid = Nanoid.generate()

      {:ok, mc_result} = Mailchimp.add_to_list(%{ test_sub | rid: remote_rid }, @main_list_id)

      {:ok, local_result} = Mailchimp.confirm_subscription(%{ test_sub | rid: local_rid }, @main_list_id)

      assert String.equivalent?(local_result.email, test_sub.email)
      assert String.equivalent?(local_result.rid, mc_result["merge_fields"]["RID"])
    end

    test "Returns validation error if params are wrong" do
      sub = %{ PlumaApi.Factory.subscriber() | email: "not_an_email" }
      {:error, {:validation, _error}} = Mailchimp.confirm_subscription(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | status: "not_a_status" }
      {:error, {:validation, _error}} = Mailchimp.confirm_subscription(sub, @main_list_id)

      sub = %{ PlumaApi.Factory.subscriber() | email: "" }
      {:error, {:validation, _error}} = Mailchimp.confirm_subscription(sub, @main_list_id)
    end

  end

end
