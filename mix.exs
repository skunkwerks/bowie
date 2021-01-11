defmodule Bowie.MixProject do
  use Mix.Project

  def project() do
    [tag, description] = version()

    [
      name: "Bowie",
      version: tag,
      description: "bowie " <> description,
      package: package(),
      app: :bowie,
      elixir: "~> 1.11",
      docs: [
        extras: ["README.md"],
        source_url: "https://github.com/skunkwerks/bowie"
      ],
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application() do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      files: ~w(lib mix.exs README.md LICENSE .version),
      maintainers: ["dch"],
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/skunkwerks/bowie"}
    ]
  end

  defp deps() do
    [
      {:bypass, "~> 1.0", only: :test},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22", only: [:dev], runtime: false},
      {:mint, "~> 1.2"},
      {:recon, "~> 2.5", only: [:dev], runtime: false}
    ]
  end

  defp version() do
    case File.dir?(".git") do
      false -> from_hex()
      true -> from_git()
    end
  end

  defp from_hex() do
    File.read!(".version") |> String.split(":")
  end

  defp from_git() do
    # pulls version information from "nearest" git tag or sha hash-ish
    {hashish, 0} =
      System.cmd("git", ~w[describe --dirty --abbrev=7 --tags --always --first-parent])

    full_version = String.trim(hashish)

    tag_version =
      hashish
      |> String.split("-")
      |> List.first()
      |> String.replace_prefix("v", "")
      |> String.trim()

    tag_version =
      case Version.parse(tag_version) do
        :error -> "0.0.0-#{tag_version}"
        _ -> tag_version
      end

    # stash the tag so that it's rolled into the next commit and therefore
    # available in hex packages when git tag info may not be present
    File.write!(".version", "#{tag_version}: #{full_version}")

    [tag_version, full_version]
  end
end
