defmodule PlumaApi.TestUtils do
  @moduledoc """
  Utilities for testing.
  """

  #Included to ensure we're calling ExUnit.DataCase before macro call.
  @callback on_exit(term, (() -> term)) :: :ok

  defmacro __using__([]) do
    quote do
      alias PlumaApi.Mailchimp
      @behaviour PlumaApi.TestUtils
      @main_list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

      setup :remove_test_subs_from_mailchimp

      @doc """
      Passed as an `atom` into the `setup` macro for tests where mailchimp subscribers
      are added to our Mailchimp audience. This function deletes said subscribers, notifying
      us via a debug statement if the deletion was successful or unsuccessful.

      Subscribers to be used in a test function must be declared outside said function and immediately
      before it via the following tag:

      `@tag test_sub: PlumaApi.Factory.subscriber` where test_sub is a struct containing raw subscriber information.

      TODO: Create a version that accomodates multiple subscribers.
      """
      def remove_test_subs_from_mailchimp(%{test_sub: test_sub}) do
        on_exit(fn -> 
          IO.puts("Deleting test email #{test_sub.email} from Mailchimp API")
          case Mailchimp.delete_subscriber(test_sub.email, @main_list_id) do
            {:ok, _} -> IO.puts("Deleted #{test_sub.email} succesfully")
            {:error, error} -> 
              IO.puts("Could not delete #{test_sub.email}. Status was #{error["status"]}")
          end
        end)
      end
      def remove_test_subs_from_mailchimp(_context), do: :ok

      defoverridable remove_test_subs_from_mailchimp: 1
    end
  end

end
