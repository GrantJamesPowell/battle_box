defmodule BattleBox.Games.Marooned.Error do
  alias BattleBox.Game.Error

  defmodule InvalidInputFormat do
    @enforce_keys [:input]
    defstruct [:input]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{input: _input}) do
        """
        You need to format it correctly
        """
      end
    end
  end

  defmodule CannotMoveToNonAdjacentSquare do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You have to move adjacently
        """
      end
    end
  end

  defmodule CannotMoveToSquareYouAlreadyOccupy do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You can't move into the space you're already in
        """
      end
    end
  end

  defmodule CannotMoveIntoOpponent do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You can't move into an opponent
        """
      end
    end
  end

  defmodule CannotMoveOffBoard do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You can't move off the board
        """
      end
    end
  end

  defmodule CannotMoveIntoRemovedSquare do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You can't move into a removed space!
        """
      end
    end
  end

  defmodule CannotRemoveSquareAPlayerIsOn do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You tried to move into the same square that you're removing!!
        """
      end
    end
  end

  defmodule CannotRemoveASquareAlreadyRemoved do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You tried to move into the same square that you're removing!!
        """
      end
    end
  end

  defmodule CannotRemoveASquareOutsideTheBoard do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You tried to move into the same square that you're removing!!
        """
      end
    end
  end

  defmodule CannotRemoveSameSquareAsMoveTo do
    @enforce_keys [:target]
    defstruct [:target]

    defimpl Error do
      def level(_), do: :warn

      def to_human(%{target: _target}) do
        """
        You tried to move into the same square that you're removing!!
        """
      end
    end
  end
end