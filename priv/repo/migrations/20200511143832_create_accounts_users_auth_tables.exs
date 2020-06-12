defmodule Gabbler.Repo.Migrations.CreateAccountsUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:accounts_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:accounts_users, [:email])

    create table(:accounts_users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:accounts_users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create unique_index(:accounts_users_tokens, [:context, :token])
  end
end
