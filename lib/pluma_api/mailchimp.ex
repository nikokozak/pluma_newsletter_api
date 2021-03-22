defmodule PlumaApi.Mailchimp do
  alias PlumaApi.MailchimpRepo
  alias PlumaApi.Subscriber
  require OK

  @default_success_code 200

  defp process_response(response, success_code \\ @default_success_code) do
    case response do
      %{ status_code: ^success_code, body: body } -> {:ok, decode_response_body(body)}
      %{ status_code: _error_code, body: body } -> {:error, decode_response_body(body)}
    end
  end

  defp decode_response_body(""), do: %{}
  defp decode_response_body(body), do: Jason.decode!(body)

  def check_health() do
    MailchimpRepo.check_health()
    |> process_response
  end

  def get_subscriber(email, list_id) do
    MailchimpRepo.get_subscriber(email, list_id)
    |> process_response
  end

  def add_to_audience(subscriber, list_id, test \\ false) do
    encode_subscriber_data_for_mailchimp(subscriber, test)
    |> MailchimpRepo.add_to_audience(list_id)
    |> process_response
  end

  def tag_subscriber(email, list_id, tags) when is_list(tags) do
    MailchimpRepo.tag_subscriber(email, list_id, tags)
    |> process_response
  end

  def create_merge_field(list_id, field_name, field_type) do
    MailchimpRepo.create_merge_field(list_id, field_name, field_type)
    |> process_response
  end

  def update_merge_field(email, list_id, merge_fields) when is_map(merge_fields) do
    MailchimpRepo.update_merge_field(email, list_id, merge_fields)
    |> process_response
  end

  def check_exists(email, list_id) do
    case MailchimpRepo.check_exists(email, list_id) do
      %{status_code: 200} -> true
      _other -> false
    end
  end

  def archive_subscriber(email, list_id) do
    MailchimpRepo.archive_subscriber(email, list_id)
    |> process_response(204)
  end

  def delete_subscriber(email, list_id) do
    MailchimpRepo.delete_subscriber(email, list_id)
    |> process_response(204)
  end

  defp encode_subscriber_data_for_mailchimp(sub = %Subscriber{}, test) do
    Jason.encode!(%{
      email_address: sub.email,
      status: "subscribed",
      tags: (if test, do: ["Test"], else: []),
      merge_fields: %{
        RID: sub.rid,
        PRID: sub.parent_rid
      }
    })
  end

  # Eventually incorporate this override with the one below - for now just to make sure ip_signup doesn't block adding a sub while testing.
  defp encode_subscriber_data_for_mailchimp(%{"email"=> email, "fname" => fname, "lname" => lname, "rid" => rid, "prid" => prid, "ip_signup" => ip_signup}, test) do
    Jason.encode!(%{
      email_address: email,
      status: "pending",
      tags: (if test, do: ["Test"], else: []),
      merge_fields: %{
        FNAME: fname,
        LNAME: lname,
        RID: rid,
        PRID: prid
      },
      ip_signup: ip_signup
    })
  end

  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: ""}, external_sub, list_id), do: sync_remote_and_local_RIDs(%{ local_sub | rid: nil }, external_sub, list_id)
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: ""}, list_id) do
    OK.for do
      new_rid = Nanoid.generate()
      _remote_update <- update_remote(local_sub, %{ "RID": new_rid }, list_id)
      local_update <- update_local(local_sub, %{ rid: new_rid })
    after
      {:ok, local_update}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: nil}, _external_sub = %{rid: rid}, _list_id) do
    OK.for do
      local_update <- update_local(local_sub, %{ rid: rid })
    after
      {:ok, local_update}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: rid}, _external_sub = %{rid: ""}, list_id) do
    OK.for do
      _remote_update <- update_remote(local_sub, %{ "RID": rid }, list_id)
    after
      {:ok, local_sub}
    end
  end
  def sync_remote_and_local_RIDs(local_sub = %Subscriber{rid: local_rid}, %{rid: remote_rid}, list_id) do 
    if not String.equivalent?(local_rid, remote_rid) do
      OK.for do
        _remote_update <- update_remote(local_sub, %{ "RID": local_rid }, list_id)  
      after
        {:ok, local_sub}
      end
    else
      {:ok, local_sub}
    end
  end

  defp update_remote(subscriber = %Subscriber{}, updated_fields, list_id) when is_map(updated_fields) do
    update_merge_field(subscriber.email, list_id, updated_fields)
    |> case do
      {:ok, response} -> {:ok, response}
      {:error, _error_response} -> {:error, :remote_update_error}
    end
  end

  defp update_local(subscriber = %Subscriber{}, updated_fields) do
    Subscriber.insert_changeset(subscriber, updated_fields)
    |> PlumaApi.Repo.update
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, _chgst} -> {:error, :local_update_error}
    end
  end

end
