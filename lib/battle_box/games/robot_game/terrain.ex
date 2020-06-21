defmodule BattleBox.Games.RobotGame.Settings.Terrain.Helpers do
  def sigil_t(map, _modifiers) do
    graphs =
      map
      |> String.split("\n")
      |> Enum.map(&String.graphemes/1)
      |> Enum.reject(fn x -> x == [] end)
      |> Enum.map(&Enum.reject(&1, fn grapheme -> String.trim(grapheme) == "" end))

    rows = length(graphs)
    cols = graphs |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)

    header = <<rows::8, cols::8>>

    terrain_data =
      graphs
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(&<<&1::8>>)

    [header, terrain_data]
    |> IO.iodata_to_binary()
  end
end

defmodule BattleBox.Games.RobotGame.Settings.Terrain do
  import __MODULE__.Helpers

  @default ~t/0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 2 2 2 2 2 0 0 0 0 0 0 0
  0 0 0 0 0 2 2 1 1 1 1 1 2 2 0 0 0 0 0
  0 0 0 2 2 1 1 1 1 1 1 1 1 1 2 2 0 0 0
  0 0 0 2 1 1 1 1 1 1 1 1 1 1 1 2 0 0 0
  0 0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0 0
  0 0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0 0
  0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0
  0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0
  0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0
  0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0
  0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0
  0 0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0 0
  0 0 2 1 1 1 1 1 1 1 1 1 1 1 1 1 2 0 0
  0 0 0 2 1 1 1 1 1 1 1 1 1 1 1 2 0 0 0
  0 0 0 2 2 1 1 1 1 1 1 1 1 1 2 2 0 0 0
  0 0 0 0 0 2 2 1 1 1 1 1 2 2 0 0 0 0 0
  0 0 0 0 0 0 0 2 2 2 2 2 0 0 0 0 0 0 0
  0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0/

  def default, do: @default

  def validate(terrain) do
    with {:size_header, <<rows::8, cols::8, data::binary>>} <- {:size_header, terrain},
         {:size, rows, cols} when rows in 1..40 and cols in 1..40 <- {:size, rows, cols},
         {:data_amount_correct, true} <- {:data_amount_correct, rows * cols == byte_size(data)},
         {:illegal_bytes, []} <- {:illegal_bytes, for(<<i <- data>>, i > 2, do: i)} do
      :ok
    else
      {:size_header, _} ->
        {:error, "Illegal Size Header"}

      {:size, _rows, _cols} ->
        {:error, "Rows and cols must be between 1 and 40"}

      {:data_amount_correct, false} ->
        {:error, "Terrain data byte size must equal rows * cols"}

      {:illegal_bytes, bytes} ->
        {:error, "Terrain data must have bytes less than 2, but found bytes #{inspect(bytes)}"}
    end
  end

  def rows(<<rows::8, _cols::8, _::binary>>), do: rows
  def cols(<<_rows::8, cols::8, _::binary>>), do: cols

  def resize(<<_current_rows::8, _current_cols::8, data::binary>>, desired_rows, desired_cols) do
    # 🤷
    amount_of_bytes_needed = desired_rows * desired_cols
    replicas = Integer.floor_div(amount_of_bytes_needed, byte_size(data))

    <<new_data::binary-size(amount_of_bytes_needed), _rest::binary>> =
      :binary.copy(data, replicas + 1)

    <<desired_rows::8, desired_cols::8, new_data::binary>>
  end

  def at_location(terrain, [x, y]) do
    <<rows::8, cols::8, data::binary>> = terrain
    on_board? = x in 0..(cols - 1) && y in 0..(rows - 1)

    if on_board? do
      offset = x + cols * y

      case :binary.at(data, offset) do
        0 -> :inaccessible
        1 -> :normal
        2 -> :spawn
      end
    else
      :inaccessible
    end
  end

  def set_at_location(terrain, [x, y], type) do
    <<rows::8, cols::8, data::binary>> = terrain
    offset = x + cols * y
    <<prefix::binary-size(offset), _replace::8, suffix::binary>> = data
    <<rows::8, cols::8, prefix::binary, type_to_int(type)::8, suffix::binary>>
  end

  def dimensions(<<rows::8, cols::8, _::binary>>), do: %{rows: rows, cols: cols}

  defp type_to_int(type) do
    case type do
      :inaccessible -> 0
      :normal -> 1
      :spawn -> 2
    end
  end
end
