defmodule EctoAtom do
  @moduledoc """
  Stores an atom in a string column. Round-trips only the atoms in
  `WebLudo.Logic.Constants.valid_atoms/0`; anything else fails the
  Ecto cast/load/dump callbacks with `:error`.

  This guards against an atom-table-leak DoS that would arise from
  calling `String.to_atom/1` on arbitrary input loaded from the DB.
  """

  use Ecto.Type

  alias WebLudo.Logic.Constants

  def type, do: :string

  def cast(nil), do: {:ok, nil}

  def cast(value) when is_atom(value) do
    if value in Constants.valid_atoms(), do: {:ok, value}, else: :error
  end

  def cast(value) when is_binary(value), do: from_string(value)

  def cast(_), do: :error

  def load(nil), do: {:ok, nil}
  def load(value) when is_binary(value), do: from_string(value)
  def load(_), do: :error

  def dump(nil), do: {:ok, nil}

  def dump(value) when is_atom(value) do
    if value in Constants.valid_atoms(), do: {:ok, Atom.to_string(value)}, else: :error
  end

  def dump(_), do: :error

  defp from_string(s) do
    atom = String.to_existing_atom(s)
    if atom in Constants.valid_atoms(), do: {:ok, atom}, else: :error
  rescue
    ArgumentError -> :error
  end
end
