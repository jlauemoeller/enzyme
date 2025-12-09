defmodule IsoRefTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Enzyme.IsoRef

  describe "IsoRef.new/1" do
    test "creates a reference with name only" do
      ref = IsoRef.new(:pending)
      assert ref.name == :pending
    end
  end
end
