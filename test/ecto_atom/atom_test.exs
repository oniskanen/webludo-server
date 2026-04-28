defmodule EctoAtomTest do
  use ExUnit.Case, async: true

  describe "cast/1" do
    test "accepts a whitelisted atom" do
      assert {:ok, :red} = EctoAtom.cast(:red)
      assert {:ok, :home} = EctoAtom.cast(:home)
      assert {:ok, :none} = EctoAtom.cast(:none)
    end

    test "converts a whitelisted string to its atom" do
      assert {:ok, :blue} = EctoAtom.cast("blue")
      assert {:ok, :goal} = EctoAtom.cast("goal")
    end

    test "rejects an atom outside the whitelist" do
      assert :error = EctoAtom.cast(:purple)
      assert :error = EctoAtom.cast(:not_a_color)
    end

    test "rejects an unknown string without creating a new atom" do
      assert :error = EctoAtom.cast("never_seen_this_string_before_2026")
    end

    test "rejects non-atom non-string input" do
      assert :error = EctoAtom.cast(42)
      assert :error = EctoAtom.cast(%{})
      assert :error = EctoAtom.cast([])
    end

    test "passes nil through" do
      assert {:ok, nil} = EctoAtom.cast(nil)
    end
  end

  describe "load/1" do
    test "loads a whitelisted string into its atom" do
      assert {:ok, :red} = EctoAtom.load("red")
      assert {:ok, :center} = EctoAtom.load("center")
    end

    test "rejects an unknown string without creating a new atom" do
      assert :error = EctoAtom.load("not_a_real_atom_value_xyz")
    end

    test "rejects non-binary input" do
      assert :error = EctoAtom.load(42)
      assert :error = EctoAtom.load(:red)
    end

    test "passes nil through" do
      assert {:ok, nil} = EctoAtom.load(nil)
    end
  end

  describe "dump/1" do
    test "dumps a whitelisted atom to its string" do
      assert {:ok, "yellow"} = EctoAtom.dump(:yellow)
      assert {:ok, "play"} = EctoAtom.dump(:play)
    end

    test "rejects an atom outside the whitelist" do
      assert :error = EctoAtom.dump(:not_in_whitelist)
    end

    test "rejects non-atom input" do
      assert :error = EctoAtom.dump("red")
      assert :error = EctoAtom.dump(42)
    end

    test "passes nil through" do
      assert {:ok, nil} = EctoAtom.dump(nil)
    end
  end
end
