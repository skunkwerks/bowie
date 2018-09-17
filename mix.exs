defmodule Bowie.MixProject do
  use Mix.Project

  def project() do
    {tag, description} = git_version()

    [
      name: "Bowie",
      description: description() <> description,
      package: package(),
      app: :bowie,
      version: tag,
      elixir: "~> 1.7",
      docs: [
        extras: "README.md",
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
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/skunkwerks/bowie"}
    ]
  end

  defp deps() do
    [
      {:bypass, "~> 0.8", only: :test},
      {:dialyxir, "~> 1.0.0-rc.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.19", only: [:dev], runtime: false},
      {:ibrowse, "~> 4.4.1"},
      {:icouch, "~> 0.5.1"},
      {:recon, "~> 2.3.2", only: [:dev], runtime: false}
    ]
  end

  defp description() do
    """
    Bowie knows all about Changes.

    Bowie uses the very nice `ICouch` and `ibrowse` libraries to provide
    a silky smooth failure-tolerant OTP-compatible worker around Apache
    CouchDB's per-database changes feed, with an async message per doc.
    """
  end

  defp git_version() do
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
        :error -> "0.0.0-git.#{tag_version}"
        _ -> tag_version
      end

    {tag_version, full_version}
  end
end
