defmodule Enzyme.Iso.BuiltinsTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Enzyme.Iso
  alias Enzyme.Iso.Builtins

  describe "Builtins.names/0" do
    test "returns list of available builtins" do
      names = Builtins.names()
      assert :integer in names
      assert :float in names
      assert :atom in names
      assert :base64 in names
      assert :json in names
    end
  end

  describe "Builtins.get/1" do
    test "returns nil for unknown names" do
      assert Builtins.get(:unknown) == nil
      assert Builtins.get(:nonexistent) == nil
    end

    test "returns iso for known names" do
      iso = Builtins.get(:integer)
      assert %Iso{forward: fwd, backward: bwd} = iso
      assert is_function(fwd, 1)
      assert is_function(bwd, 1)
    end
  end

  describe ":integer builtin" do
    test "converts string to integer (forward)" do
      iso = Builtins.integer()
      assert iso.forward.("42") == 42
      assert iso.forward.("-17") == -17
      assert iso.forward.("0") == 0
    end

    test "converts integer to string (backward)" do
      iso = Builtins.integer()
      assert iso.backward.(42) == "42"
      assert iso.backward.(-17) == "-17"
      assert iso.backward.(0) == "0"
    end
  end

  describe ":float builtin" do
    test "converts string to float (forward)" do
      iso = Builtins.float()
      assert iso.forward.("3") == 3.0
      assert iso.forward.("3.14") == 3.14
      assert iso.forward.("-2.5") == -2.5
      assert iso.forward.("0.0") == 0.0
    end

    test "converts float to string (backward)" do
      iso = Builtins.float()
      result = iso.backward.(3.14)
      assert is_binary(result)
      assert String.contains?(result, "3.14")
    end
  end

  describe ":atom builtin" do
    test "converts string to atom (forward)" do
      iso = Builtins.atom_iso()
      assert iso.forward.("hello") == :hello
      assert iso.forward.("foo_bar") == :foo_bar
    end

    test "converts atom to string (backward)" do
      iso = Builtins.atom_iso()
      assert iso.backward.(:hello) == "hello"
      assert iso.backward.(:foo_bar) == "foo_bar"
    end
  end

  describe ":base64 builtin" do
    test "decodes base64 string (forward)" do
      iso = Builtins.base64()
      encoded = Base.encode64("hello world")
      assert iso.forward.(encoded) == "hello world"
    end

    test "encodes to base64 string (backward)" do
      iso = Builtins.base64()
      assert iso.backward.("hello world") == Base.encode64("hello world")
    end

    test "roundtrip works correctly" do
      iso = Builtins.base64()
      original = "some binary data"
      encoded = iso.backward.(original)
      decoded = iso.forward.(encoded)
      assert decoded == original
    end
  end

  describe ":date builtin" do
    test "converts string to Date (forward)" do
      iso = Builtins.date()
      assert iso.forward.("2024-01-01") == ~D[2024-01-01]
    end

    test "converts Date to string (backward)" do
      iso = Builtins.date()
      assert iso.backward.(~D[2024-01-01]) == "2024-01-01"
    end

    test "roundtrip works correctly" do
      iso = Builtins.date()
      original = ~D[2024-12-31]
      str = iso.backward.(original)
      result = iso.forward.(str)
      assert result == original
    end
  end

  describe ":time builtin" do
    test "converts string to Time (forward)" do
      iso = Builtins.time()
      assert iso.forward.("12:34:56") == ~T[12:34:56]
    end

    test "converts Time to string (backward)" do
      iso = Builtins.time()
      assert iso.backward.(~T[12:34:56]) == "12:34:56"
    end

    test "roundtrip works correctly" do
      iso = Builtins.time()
      original = ~T[23:45:01]
      str = iso.backward.(original)
      result = iso.forward.(str)
      assert result == original
    end
  end

  describe ":iso8601 builtin" do
    test "converts string to DateTime (forward)" do
      iso = Builtins.iso8601()
      {:ok, expected, _} = DateTime.from_iso8601("2024-01-01T12:34:56Z")
      assert iso.forward.("2024-01-01T12:34:56Z") == expected
    end

    test "converts DateTime to string (backward)" do
      iso = Builtins.iso8601()
      {:ok, datetime, _offset} = DateTime.from_iso8601("2024-01-01T12:34:56+01:00")
      assert iso.backward.(datetime) == "2024-01-01T11:34:56Z"
    end

    test "roundtrip works as expected" do
      iso = Builtins.iso8601()
      {:ok, original, _offset} = DateTime.from_iso8601("2024-01-01T12:34:56+01:00")
      str = iso.backward.(original)
      result = iso.forward.(str)
      assert result == ~U[2024-01-01 11:34:56Z]
    end
  end
end
