defmodule BattleBox.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table("users") do
      add :github_id, :integer, null: false
      add :github_avatar_url, :text, null: false
      add :github_login_name, :text, null: false
      add :is_admin, :boolean, default: false, null: false
      add :is_banned, :boolean, default: false, null: false
      timestamps()
    end

    create index("users", [:github_id], unique: true)
    create index("users", [:github_login_name], unique: true)
  end
end
