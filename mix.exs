defmodule Bowie.MixProject do
  use Mix.Project

  def project() do
    [
      name: "Bowie",
      description: description(),
      package: package(),
      app: :bowie,
      version: set_version(),
      elixir: "~> 1.7",
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

  # stash the tag so that it's rolled into the next commit and therefore
  # available in hex packages when git tag info may not be present
  defp set_version() do
    v = get_version()
    File.write!(".version", v)
    v
  end

  defp get_version() do
    # get version from closest git tag, last saved tag, or assume 0.0.0-alpha
    get_version(File.read(".version"), File.dir?(".git"), System.find_executable("git"))
    |> String.replace_prefix("v", "")
    |> String.trim_trailing()
  end

  # fallback when there is no actual error, just missing information
  defp get_version(:missing), do: "0.0.0-alpha"
  # no .version file, must be first run: assume lowest possible version
  defp get_version({:error, _}, _, _), do: get_version(:missing)
  # .version exists, but no .git dir, probably inside hex package
  defp get_version({:ok, v}, false, _), do: v
  # .version exists, and we can read git tags
  defp get_version({:ok, _}, true, git) when is_binary(git) do
    case System.cmd("git", ~w[describe --dirty --abbrev=0 --tags --first-parent],
           stderr_to_stdout: true
         ) do
      {v, 0} -> v
      _ -> get_version(:missing)
    end
  end

  # something is very wrong so we give up and hex publishing will fail
  defp get_version(_, _, _), do: "unknown"
end
