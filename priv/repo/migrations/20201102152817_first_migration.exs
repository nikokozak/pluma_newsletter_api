defmodule PlumaApi.Repo.Migrations.FirstMigration do
  use Ecto.Migration

  def change do

    create table(:subscribers, primary_key: false) do

      add :id, :uuid, primary_key: true

      add :mchimp_id, :string
      add :email, :string, null: false
      add :list, :string

      add :rid, :string
      add :parent_rid, :string

    end

  end
end
