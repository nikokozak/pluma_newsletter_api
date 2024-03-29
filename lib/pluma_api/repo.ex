defmodule PlumaApi.Repo do
  use Ecto.Repo,
    otp_app: :pluma_api,
    adapter: Ecto.Adapters.Postgres
  alias PlumaApi.Subscriber

  @doc """
  Recursively writes all subscribers in the database into a text file, sorting them by the number
  of referees each has brought into the system, and indenting referees so as to make evident
  parents and children.

  Rudimentary atm. Writes to subs.txt
  """
  def list_subs_as_tree do
    file = File.open!("subs.txt", [:write, :utf8])
    PlumaApi.Subscriber
    |> PlumaApi.Repo.all
    |> sort_by_referees_num
    |> print_tree(file)
  end

  defp sort_by_referees_num(subs) do
    subs = PlumaApi.Repo.preload(subs, :referees)
    Enum.sort(subs, fn x, y -> 
      length(x.referees) > length(y.referees)
    end)
  end

  defp print_tree(subs, file) when is_pid(file), do: print_tree(file, subs, 0)
  defp print_tree(_file, [], _level), do: :ok
  defp print_tree(file, [sub | rest], level) do
    sub = PlumaApi.Repo.preload(sub, :referees)
    IO.write(file, make_print_string(sub, level))
    print_tree(file, sub.referees, level + 1)
    if (level == 0), do: IO.write(file, "\n")
    print_tree(file, rest, level)
  end

  defp make_leader_dashes(str_so_far, 0), do: str_so_far
  defp make_leader_dashes(str_so_far, level), do: make_leader_dashes(str_so_far <> "----", level - 1)
  defp make_leader_dashes(level), do: make_leader_dashes("", level) 

  defp make_print_string(sub, level) do
    case (length(sub.referees) == 0) do
      true -> "#{make_leader_dashes(level)}#{sub.email}\n"
      false -> "#{make_leader_dashes(level)}#{sub.email} | #{length(sub.referees)}\n"
    end
  end

  @doc """
  Upserts subscribers based on a CSV export of a Mailchimp Audience.

  The Mailchimp Audience MUST have the following headers:
  - `"Correo"`
  - `"Nombre"`
  - `"Apellido"`
  - `"OPTIN_IP" & "CONFIRM_IP"`
  - `"TAGS"`
  - `"RID"`
  - `"ParentRID"`
  - `"CC"`

  **Parameters**
  - `file`: relative path from application root to CSV file.
  - `status`: one of `"subscribed", "archived", "cleaned"`.
  - `list_id`: the list to which the csv subscribers belong.
  """
  def upsert_from_CSV(file, status, list_id) when status in ["subscribed", "unsubscribed", "cleaned"] do
    read_from_csv(file)
    |> Stream.each(&upsert_csv_row(&1, status, list_id))
    |> Stream.run
  end

  def upsert_csv_row(row, status, list_id) do
    Subscriber.with_email(row["Correo"])
    |> PlumaApi.Repo.one
    |> case do
      nil -> %Subscriber{}
      found -> found
    end
    |> Subscriber.changeset(csv_to_sub_params(row, status, list_id))
    |> PlumaApi.Repo.insert_or_update
    |> case do
      {:ok, sub} -> IO.inspect("Updated or inserted #{sub.email}")
      {:error, chgst} -> IO.inspect(chgst)
    end
  end

  def csv_to_sub_params(row, status, list_id) do
      %{
        email: row["Correo"],
        fname: row["Nombre"],
        lname: row["Apellido"],
        ip_signup: longest(row["OPTIN_IP"], row["CONFIRM_IP"]),
        status: status,
        tags: parse_tags(row["TAGS"]),
        mchimp_id: hashify_email(row["Correo"]),
        rid: row["RID"],
        parent_rid: row["ParentRID"],
        country: row["CC"],
        list: list_id
      }
  end

  def read_from_csv(file) do
    Path.expand(file)
    |> File.stream!
    |> CSV.decode!(headers: true)
  end

  defp parse_tags(tags) do
    String.split(tags, ", ") 
    |> Enum.map(&String.trim(&1, "\""))
  end

  defp hashify_email(email) do
    :crypto.hash(:md5, String.downcase(email)) |> Base.encode16 |> String.downcase
  end

  defp longest(a, b) do
    if String.length(a) > String.length(b),
      do: a,
    else: b
  end

end
