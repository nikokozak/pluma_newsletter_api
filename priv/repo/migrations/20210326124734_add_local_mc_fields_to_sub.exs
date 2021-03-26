defmodule PlumaApi.Repo.Migrations.AddLocalMcFieldsToSub do
  use Ecto.Migration

  def change do
    alter table(:subscribers) do
      add :status, :string
      add :fname, :string
      add :lname, :string
      add :ip_signup, :string
      add :tags, {:array, :string}
    end
  end
end
