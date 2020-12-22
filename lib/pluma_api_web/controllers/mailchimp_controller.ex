defmodule PlumaApiWeb.MailchimpController do
  use PlumaApiWeb, :controller
  alias PlumaApi.Subscriber
  alias PlumaApi.Repo
  alias PlumaApi.MailchimpRepo

  @list_id Keyword.get(Application.get_env(:pluma_api, :mailchimp), :main_list_id)

  def test_get(conn, _params) do
    conn
    |> put_status(200)
    |> json("OK")
  end

  def handle_event(conn, params = %{"type" => "subscribe"}) do
    sub_data = params["data"]
    merge_fields = sub_data["merges"]
    sub = Subscriber.insert_changeset(%Subscriber{}, %{
        email: sub_data["email"],
        mchimp_id: sub_data["id"],
        rid: merge_fields["RID"],
        parent_rid: merge_fields["PRID"],
        list: sub_data["list_id"]
    })

    case Repo.insert(sub) do
      {:ok, subscriber} ->
        maybe_update_rid(subscriber)
        maybe_tag_parent(subscriber)

        conn
        |> put_status(200)
        |> json(%{ status: "created", email: subscriber.email })
      {:error, error} ->
        conn
        |> put_status(202)
        |> json(%{ status: "error", detail: error })
    end
  end

  def handle_event(conn, params = %{"type" => "unsubscribe"}) do
    sub = Subscriber.with_email(params["data"]["email"]) 
          |> Repo.one

    case Repo.delete(sub) do
      {:ok, deleted} ->
        conn
        |> put_status(200)
        |> json(%{ status: "deleted", email: deleted.email })
      other ->
        conn
        |> put_status(202)
        |> json(%{ status: "error", detail: other })
    end
  end


  defp maybe_update_rid(subscriber = %Subscriber{rid: ""}) do
    maybe_update_rid(%{ subscriber | rid: nil })
  end

  defp maybe_update_rid(subscriber = %Subscriber{rid: nil}) do
    rid = Nanoid.generate()
    response = MailchimpRepo.update_merge_field(subscriber.email, @list_id, %{ "RID": rid })
    case response do
      {:ok, %HTTPoison.Response{status_code: 200}} ->
        IO.inspect("Updated RID field for #{subscriber.email}")
        Subscriber.insert_changeset(subscriber, %{rid: rid})
        |> Repo.update
      other ->
        IO.inspect("There was an error updating RID field for #{subscriber.email}")
        IO.inspect(other)
        {:error, other}
    end
  end

  defp maybe_update_rid(_other), do: :ok

  defp maybe_tag_parent(child) do
    if has_parent_rid(child) do
      parent = 
        Subscriber.with_rid(child.parent_rid)
        |> Subscriber.preload_referees
        |> Repo.one

      maybe_make_vip(parent)
    end
  end

  defp maybe_make_vip(parent) do
    case Map.get(parent, :referees) do
      nil -> :ok
      other ->
        if length(other) == 3 do
          {:ok, %HTTPoison.Response{ status_code: 204 }} = 
            MailchimpRepo.tag_subscriber(parent.email, @list_id, [%{ name: "VIP", status: "active" }])
        end
    end
  end

  defp has_parent_rid(child) do
    if not is_nil(child.parent_rid) and String.length(child.parent_rid) != 0 do
      true
    else
      false
    end
  end
  
end
