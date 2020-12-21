defmodule PlumaApi.Interface do
  alias PlumaApi.{MailchimpRepo, Subscriber, TransactionalAPI, Repo}
  @mailchimp_list Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  @moduledoc """
  **DEPREPCATED** -> we are no longer using the Mailchimp TransactionalAPI, nor are we
  handling subscription/unsubscription from the API. Before reactivating this module,
  make sure to add rollback functionalities for the different steps in the Multi flows.

  Interface has two publically accessible methods - `subscribe` and `unsubscribe`.

  Each compiles a series of functions from the `MailchimpRepo`, `Subscriber`, and
  `TransactionalAPI` modules in order to handle the entire subscription and unsubscription
  flow for subscribers.

  `subscribe` and `unsubscribe` both rely on the `Ecto.Multi` paradigm to operate. 
  """

  @doc """
  Handles, using an Ecto Multi, the transactions necessary to add a new subscriber 
  (checking the new sub is not already present) to both the application database 
  and the external Mailchimp audience list. Will also send out a welcome email
  if the previous operations are succesful.
  """
  def subscribe(email, parent_rid) do
    subscriber = Subscriber.make(email, parent_rid)
    
    multi = 
      Ecto.Multi.new
      |> Ecto.Multi.run(:exists, &ensure_not_exists(&1, &2, email))
      |> Ecto.Multi.insert(:subscriber, Subscriber.insert_changeset(%Subscriber{}, subscriber))
      |> Ecto.Multi.run(:mailchimp, &handle_mailchimp_sub_add(&1, &2))
      |> Ecto.Multi.run(:transactional, &handle_welcome_email(&1, &2))

    Repo.transaction(multi)
  end

  @doc """
  Handles, using an Ecto Multi, the transactions necessary to unsubscribe a subscriber
  from the external Mailchimp audience, as well as the internal datbase. Sends out a
  unsubscribed email if all previous operations are succesful. 
  """
  def unsubscribe(email) do
    multi =
      Ecto.Multi.new
      |> Ecto.Multi.run(:exists, &ensure_exists(&1, &2, email))
      |> Ecto.Multi.run(:mailchimp, &handle_mailchimp_archive(&1, &2, email))
      |> Ecto.Multi.run(:delete, &handle_subscriber_delete(&1, &2))
      |> Ecto.Multi.run(:transactional, &handle_unsubscribe_email(&1, &2, email))

    Repo.transaction(multi)
  end

  defp ensure_not_exists(_repo, _progress, email) do
    case Subscriber.with_email(email) |> Repo.one do
      nil -> {:ok, :not_exists}
      subscriber -> {:error, subscriber}
    end
  end

  defp ensure_exists(_repo, _progress, email) do
    case Subscriber.with_email(email) |> Repo.one do
      nil -> {:error, :not_exists}
      subscriber -> {:ok, subscriber}
    end
  end

  defp handle_mailchimp_sub_add(_repo, progress) do
    subscriber = progress.subscriber

    case MailchimpRepo.add_to_audience(subscriber, @mailchimp_list) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, other} -> 
        {:error, other}
    end
  end

  defp handle_welcome_email(_repo, progress) do
    email = progress.subscriber.email
    case TransactionalAPI.send_welcome_email(email) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, other} -> 
        {:error, other}
    end
  end

  defp handle_mailchimp_archive(_repo, _progress, email) do
    case MailchimpRepo.archive_subscriber(email, @mailchimp_list) do
      {:ok, email} -> {:ok, email}
      {:error, error} -> {:error, error}
    end
  end

  defp handle_unsubscribe_email(_repo, _progress, email) do
    case TransactionalAPI.send_unsubscribe_email(email) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, other} ->
        {:error, other}
    end
  end

  defp handle_subscriber_delete(repo, progress) do
    repo.delete(progress.exists)
  end
end
