defmodule PlumaApi.Repo do
  use Ecto.Repo,
    otp_app: :pluma_api,
    adapter: Ecto.Adapters.Postgres
end
