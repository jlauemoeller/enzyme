defmodule Enzyme.Iso.Builtins do
  @moduledoc """
  Built-in isomorphisms that are always available.

  These isos can be used in path expressions without passing them in opts:

      Enzyme.select(%{"count" => "42"}, "count::integer")
      # => 42

  ## Available Builtins

  ### Standard Library (always available)

  - `:integer` - String <-> Integer conversion
  - `:float` - String <-> Float conversion
  - `:atom` - String <-> Atom conversion
  - `:base64` - Base64 encoded string <-> Decoded binary
  - `:time` - Time string <-> Time struct
  - `:date` - Date string <-> Date struct
  - `:iso8601` - ISO8601 string <-> DateTime struct

  ### Optional Dependencies

  - `:json` - JSON string <-> Elixir term (requires Jason library)

  ## Overriding Builtins

  User-defined isos with the same name take precedence over builtins:

      # Override the :integer builtin with custom behavior
      my_integer = Enzyme.Iso.new(
        fn s -> String.to_integer(s) * 2 end,  # double on read
        fn i -> Integer.to_string(div(i, 2)) end)

      Enzyme.select(%{"n" => "10"}, "n::integer", integer: my_integer)
      # => 20

  """

  alias Enzyme.Iso

  @doc """
  Returns the builtin iso for the given name, or nil if not found.
  """
  @spec get(atom()) :: Iso.t() | nil
  def get(:integer), do: integer()
  def get(:float), do: float()
  def get(:atom), do: atom_iso()
  def get(:base64), do: base64()
  def get(:json), do: json()
  def get(:time), do: time()
  def get(:date), do: date()
  def get(:iso8601), do: iso8601()
  def get(_), do: nil

  @doc """
  Returns a list of all available builtin iso names.
  """
  @spec names() :: [atom()]
  def names do
    [:integer, :float, :atom, :base64, :json]
  end

  @doc """
  String <-> Integer conversion.

      Enzyme.select(%{"count" => "42"}, "count::integer")
      # => 42

      Enzyme.transform(%{"count" => "42"}, "count::integer", &(&1 + 1))
      # => %{"count" => "43"}
  """
  @spec integer() :: Iso.t()
  def integer do
    Iso.new(&String.to_integer/1, &Integer.to_string/1)
  end

  @doc """
  String <-> Float conversion.

      Enzyme.select(%{"rate" => "3.14"}, "rate::float")
      # => 3.14
  """
  @spec float() :: Iso.t()
  def float do
    Iso.new(
      fn string ->
        {float, ""} = Float.parse(string)
        float
      end,
      fn float -> :erlang.float_to_binary(float, [:compact, decimals: 15]) end
    )
  end

  @doc """
  String <-> Atom conversion.

  **Warning**: Creates atoms dynamically. Use with caution on untrusted input.

      Enzyme.select(%{"status" => "active"}, "status::atom")
      # => :active
  """
  @spec atom_iso() :: Iso.t()
  def atom_iso do
    Iso.new(&String.to_atom/1, &Atom.to_string/1)
  end

  @doc """
  Base64 encoded string <-> Decoded binary.

      encoded = Base.encode64("hello")
      Enzyme.select(%{"data" => encoded}, "data::base64")
      # => "hello"
  """
  @spec base64() :: Iso.t()
  def base64 do
    Iso.new(&Base.decode64!/1, &Base.encode64/1)
  end

  @doc """
  JSON string <-> Elixir term.

  Requires the Jason library. Raises a helpful error if Jason is not available.

      Enzyme.select(%{"config" => ~s({"debug": true})}, "config::json")
      # => %{"debug" => true}
  """
  @spec json() :: Iso.t()
  def json do
    Iso.new(&json_decode!/1, &json_encode!/1)
  end

  defp json_decode!(string) do
    case Code.ensure_loaded(Jason) do
      {:module, _} ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(Jason, :decode!, [string])

      {:error, _} ->
        raise ArgumentError,
              "The :json iso requires the Jason library. " <>
                "Add {:jason, \"~> 1.0\"} to your dependencies, or " <>
                "provide a custom :json iso in opts."
    end
  end

  defp json_encode!(term) do
    case Code.ensure_loaded(Jason) do
      {:module, _} ->
        # credo:disable-for-next-line Credo.Check.Refactor.Apply
        apply(Jason, :encode!, [term])

      {:error, _} ->
        raise ArgumentError,
              "The :json iso requires the Jason library. " <>
                "Add {:jason, \"~> 1.0\"} to your dependencies, or " <>
                "provide a custom :json iso in opts."
    end
  end

  @doc """
  ISO8601 date string <-> Date struct.
  """

  @spec date() :: Iso.t()
  def date do
    Iso.new(&Date.from_iso8601!/1, &Date.to_iso8601/1)
  end

  @doc """
  ISO8601 time string <-> Time struct.
  """

  @spec time() :: Iso.t()
  def time do
    Iso.new(&Time.from_iso8601!/1, &Time.to_iso8601/1)
  end

  @doc """
  ISO8601 datetime string <-> DateTime struct.

  > NOTE -- the iso normalizes to UTC so `backward(forward("2024-01-15T10:30:00+05:00"))`
  > yields `"2024-01-15T05:30:00Z"`
  """

  @spec iso8601() :: Iso.t()
  def iso8601 do
    Iso.new(
      fn string ->
        {:ok, utc, _offset} = DateTime.from_iso8601(string)
        utc
      end,
      &DateTime.to_iso8601/1
    )
  end
end
