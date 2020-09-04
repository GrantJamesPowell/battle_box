defmodule BattleBox.Games.Marooned.Logic do
  import BattleBox.Utilities.Grid, only: [manhattan_distance: 2]

  def calculate_turn(game, commands) do
    available_to_move_to = available_adjacent_locations_for_player(game, game.next_player)
    available_to_be_removed = available_to_be_removed(game)

    commands =
      case commands[game.next_player] do
        commands when is_map(commands) -> commands
        _anythin_else -> %{}
      end

    to =
      if commands["to"] in available_to_move_to do
        commands["to"]
      else
        Enum.max_by(available_to_move_to, fn location ->
          Enum.sum(
            for {player, position} <- player_positions(game),
                player != game.next_player,
                do: manhattan_distance(position, location)
          )
        end)
      end

    remove =
      if commands["remove"] in available_to_be_removed do
        commands["remove"]
      else
        enemy_adjacent_opportunities =
          available_adjacent_locations_for_player(game, opponent(game.next_player))

        Enum.min_by(enemy_adjacent_opportunities, &manhattan_distance(&1, [0, 0]))
      end

    event = %{turn: game.turn, player: game.next_player, removed_location: remove, to: to}

    game = update_in(game.events, &[event | &1])
    game = update_in(game.turn, &(&1 + 1))
    update_in(game.next_player, &opponent/1)
  end

  def winner(game) do
    game.winner

    cond do
      game.winner -> game.winner
      over?(game) -> opponent(game.next_player)
      true -> nil
    end
  end

  def over?(game) do
    available_adjacent_locations_for_player(game, game.next_player) == []
  end

  def score(game, turn \\ nil) do
    turn = turn || game.turn

    for {player, _} <- player_positions(game, turn),
        into: %{},
        do: {player, length(available_adjacent_locations_for_player(game, player, turn))}
  end

  def player_positions(game, turn \\ nil) do
    turn = turn || game.turn

    recent_positions =
      game.events
      |> Enum.filter(&(&1.turn < turn))
      |> Enum.group_by(& &1.player)
      |> Map.new(fn {player, events} ->
        %{to: location} = Enum.max_by(events, & &1.turn)
        {player, location}
      end)

    Map.merge(player_starting_locations(game), recent_positions)
  end

  def removed_locations(game, turn \\ nil) do
    events =
      if turn,
        do: Enum.filter(game.events, &(&1.turn <= turn)),
        else: game.events

    for(%{removed_location: location} <- events, do: location) ++ game.starting_removed_locations
  end

  def available_to_be_removed(game, turn \\ nil) do
    turn = turn || game.turn

    removed = removed_locations(game, turn)
    occupied = Map.values(player_positions(game, turn))

    for row <- 0..(game.rows - 1),
        col <- 0..(game.cols - 1),
        [row, col] not in removed,
        [row, col] not in occupied,
        do: [row, col]
  end

  def available_adjacent_locations_for_player(game, player, turn \\ nil) do
    turn = turn || game.turn

    %{^player => current_position} = player_positions = player_positions(game, turn)

    taken = Map.values(player_positions)
    removed = removed_locations(game, turn)

    for [x, y] <- adjacent(current_position),
        [x, y] not in taken,
        [x, y] not in removed,
        0 <= x && x < game.cols,
        0 <= y && y < game.rows,
        do: [x, y]
  end

  def opponent(player), do: %{1 => 2, 2 => 1}[player]

  defp adjacent([x, y]) do
    for(
      offset_x <- [-1, 0, 1],
      offset_y <- [-1, 0, 1],
      do: [offset_x + x, offset_y + y]
    ) -- [[x, y]]
  end

  defp player_starting_locations(game) do
    if game.player_starting_locations do
      game.player_starting_locations
    else
      x = div(game.cols, 2)
      %{1 => [x, 0], 2 => [x, game.rows - 1]}
    end
  end
end
