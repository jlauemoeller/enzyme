defmodule Enzyme.Tracer do
  @moduledoc false

  defstruct [:traced]

  import Enzyme.Guards
  import Enzyme.Tracing
  import Enzyme.Wraps

  alias Enzyme.Protocol
  alias Enzyme.Tracer
  alias Enzyme.Types

  @type t :: %Tracer{}

  @default_tracer {false, 0, :stdio}

  @spec select(Tracer.t(), Types.wrapped()) :: Types.wrapped()
  @spec select(Tracer.t(), Types.wrapped(), Types.tracer()) :: Types.wrapped()

  def new(lens) do
    %Tracer{traced: lens}
  end

  def select(lens, data, tracer \\ @default_tracer)

  def select(%Tracer{} = lens, data, tracer) do
    trace(:next, lens.traced, data, tracer)
    Protocol.select(lens.traced, data, inc(tracer))
  rescue
    e ->
      trace(:exception, lens.traced, data, tracer)
      reraise e, __STACKTRACE__
  end

  @spec transform(Tracer.t(), any(), (any() -> any())) :: any()
  def transform(lens, data, fun, tracer \\ @default_tracer)

  def transform(%Tracer{} = lens, data, fun, tracer) when is_transform(fun) do
    trace(:next, lens.traced, data, tracer)

    Protocol.transform(
      lens.traced,
      data,
      fn item ->
        Enzyme.Tracing.trace(:match, single(fun.(item)), inc(tracer)) |> unwrap()
      end,
      inc(tracer)
    )
  rescue
    e ->
      trace(:exception, lens.traced, data, tracer)
      reraise e, __STACKTRACE__
  end
end

defimpl Enzyme.Protocol, for: Enzyme.Tracer do
  alias Enzyme.Types
  alias Enzyme.Tracer

  @spec select(Tracer.t(), Types.wrapped()) :: any()
  @spec select(Tracer.t(), Types.wrapped(), Types.tracer()) :: any()
  def select(lens, collection), do: Tracer.select(lens, collection)
  def select(lens, collection, tracer), do: Tracer.select(lens, collection, tracer)

  @spec transform(Tracer.t(), Types.wrapped(), (any() -> any())) :: any()
  @spec transform(Tracer.t(), Types.wrapped(), (any() -> any()), Types.tracer()) :: any()
  def transform(lens, collection, fun), do: Tracer.transform(lens, collection, fun)

  def transform(lens, collection, fun, tracer),
    do: Tracer.transform(lens, collection, fun, tracer)
end

defimpl String.Chars, for: Enzyme.Tracer do
  alias Enzyme.Tracer
  def to_string(%Tracer{traced: lens}), do: String.Chars.to_string(lens)
end
