defmodule Enzyme.MixProject do
  @moduledoc false
  use Mix.Project

  def project do
    [
      app: :enzyme,
      version: "0.1.0",
      elixir: "~> 1.18",
      description:
        "A powerful Elixir library for querying and transforming deeply nested data structures using an expressive path syntax.",
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      source_url: "https://github.com/jlauemoeller/enzyme",
      homepage_url: "https://github.com/jlauemoeller/enzyme"
    ]
  end

  def application, do: []

  defp deps do
    [
      {:mix_test_watch, "~> 1.4", only: :dev, runtime: false},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "Enzyme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      contributors: ["Jacob Lauemøller"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/jlauemoeller/enzyme"}
    ]
  end

  defp aliases do
    [
      tdd: ["test.watch --stale --max-failures 1 --trace --seed 0"]
    ]
  end
end
