ExUnit.configure(exclude: :skip)
ExUnit.start()
Faker.start()
Ecto.Adapters.SQL.Sandbox.mode(PlumaApi.Repo, :manual)
