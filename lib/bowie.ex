# Copyright (c) 2017 MeetNow! GmbH
# Copyright (c) 2018 SkunkWerks GmbH

defmodule Bowie do
  @moduledoc """
  A GenServer-based module that listens to your CouchDB Changes.

  While Bowie can be used directly, in the iex console, it is designed to drop
  into a typical OTP Supervisor tree and receive a stream of changes from it's
  linked ibrowse worker.

  See the README.md for general usage.
  """

  # hopefully you are only using this while testing
  @couch "http://admin:passwd@127.0.0.1:5984/"

  @doc """
  Prepares an ICouch connection and verifies you have
  sufficient permissions to access the database.

  ## Examples

      Bowie.db("http://127.0.0.1:5984/", "_users")

  """
  def db(couch \\ @couch, db) do
    couch
    |> ICouch.server_connection()
    |> ICouch.open_db!(db)
  end

  @doc """
  Starts a worker, linked directly to the current process.

  ## Examples

   Bowie.db("http://127.0.0.1:5984/", "_users") |> Bowie.start()

  """
  def start(db, opts \\ [include_docs: true]) do
    start_link(db, opts)
  end

  @highlighting [number: :yellow, atom: :cyan, string: :green, nil: :magenta, boolean: :magenta]
  def debug(any) do
    IO.inspect(any, label: __MODULE__, syntax_colors: @highlighting, width: 0)
  end

  ## GenServery

  use GenServer
  require Logger

  def start_link(db, opts \\ [], gen_opts \\ []) do
    GenServer.start_link(__MODULE__, [db, opts], gen_opts)
  end

  def child_spec(opts) do
    # the only difference to the typical Supervisor.child_spec/1 is
    # that Bowie doesn't wrap the opts in list before passing them on.
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  ## Callbacks

  @impl true
  def init([db, opts]) do
    {seq, _opts} = Keyword.pop(opts, :since)

    Logger.debug(
      "Bowie changes listener #{inspect(self())} started" <>
        "#{if seq == nil, do: "", else: " since "}#{if seq != nil, do: seq, else: ""}."
    )

    {:ok, _} = Bowie.Changes.start_link(db, opts)
  end
end

defmodule Bowie.Changes do
  @moduledoc """
  Supporting module for Bowie to provide a separate mailbox queue for
  received changes independent of the ibrowse worker that does the
  actual work. This is the functionality you override with your own
  handle_change functionality.
  """

  use ChangesFollower

  def start_link(db, opts) do
    ChangesFollower.start_link(__MODULE__, [db, opts, self()])
  end

  def init([db, opts, pid]),
    do: {:ok, db, opts, pid}

  def handle_change(change, pid) do
    Bowie.debug(change)
    {:ok, pid}
  end
end
