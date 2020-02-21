defmodule BattleBox.Repo.Migrations.CreateRobotGames do
  use Ecto.Migration

  def change do
    create table("robot_games") do
      add :events, :jsonb, null: false, default: fragment("'[]'::jsonb")
      add :turn, :integer, null: false
      add :settings_id, :uuid, null: false
      timestamps()
    end

    create table("robot_game_settings") do
      add :robot_hp, :integer, null: false
      add :spawn_every, :integer, null: false
      add :spawn_per_player, :integer, null: false
      add :attack_damage, :jsonb, null: false
      add :collision_damage, :jsonb, null: false
      add :suicide_damage, :jsonb, null: false
      add :max_turns, :integer, null: false
    end
  end
end
