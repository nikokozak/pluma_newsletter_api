defmodule PlumaApi.Repo do
  use Ecto.Repo,
    otp_app: :pluma_api,
    adapter: Ecto.Adapters.Postgres

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
end
