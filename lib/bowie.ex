# Copyright (c) 2018-2038 SkunkWerks GmbH

defmodule Bowie do
  @moduledoc """
  A GenServer-based module that listens to your CouchDB Changes.

  While Bowie can be used directly, in the iex console, it is designed to drop
  into a typical OTP Supervisor tree and receive a stream of changes from it's
  linked ibrowse worker.

  See the README.md for general usage.
  """

  use GenServer
  require Logger

  # hopefully you are only using this while testing
  @couch_uri "http://admin:passwd@localhost:5984/"
  @couch_db "_users"
  @couch_changes "/_changes?feed=continuous&heartbeat=45000&include_docs=true&since=0"
  @couch_inet6 %{tcp_opts: [:inet6]}
  @changes_uri @couch_uri <> @couch_db <> @couch_changes

  defstruct(
    # can also be :unix or :http2 see gun docs
    protocol: :http,
    # not optional
    host: nil,
    # the most relaxed of all TCP ports
    port: 5984,
    # the path to be passed to `GET :5984/...`
    feed: nil,
    # hide authn headers in an anonymous fun
    headers_fun: nil,
    # tweak TLS or TCP options in gen_tcp
    options: nil,
    gun_pid: nil,
    gun_ref: nil,
    # response headers from CouchDB
    couch_ref: nil,
    # binary
    buffer: ""
  )

  # GenServer Callbacks
  @impl true
  def init([uri, opts]) do
    {:ok, _changes} = connect(uri, opts)
  end

  # @impl true
  # def handle_call(msg, from, state) do
  #   {:reply, :reply, state}
  # end

  # GenServer gun events
  # 200 OK contains the CouchDB supplied headers which includes a handy
  # couch-request-id for debugging, and when the stream was started
  @impl true
  def handle_info({:gun_response, _pid, _ref, :nofin, 200, headers}, state) do
    {:noreply, %__MODULE__{state | couch_ref: headers}}
  end

  # any non-200 response from CouchDB is a non-recoverable error
  @impl true
  def handle_info({:gun_response, _pid, _ref, :nofin, response, headers}, state) do
    {:stop, {:invalid_http_response, response}, %__MODULE__{state | couch_ref: headers}}
  end

  # got a random chunk we only care if it contains a newline
  @impl true
  def handle_info({:gun_data, _pid, _ref, :nofin, chunk}, %{buffer: buffer} = state)
      when is_binary(chunk) do
    # split by newline and pass full chunks back in buffered state
    case split_by_newline(buffer, chunk) do
      # no newline found ergo we are still in the middle of a change.
      {new_buffer, []} ->
        {:noreply, %__MODULE__{state | buffer: new_buffer}}

      # a newline was found and our changes need to be processed. Pass them to
      # our continue callback which will send it to user-specified function.
      {new_buffer, changes} ->
        {:noreply, %__MODULE__{state | buffer: new_buffer}, {:continue, {:changes, changes}}}
    end
  end

  @doc """
  Splits 2 binaries by newline, returning a tuple comprising any remaining
  buffer, and either the empty list, or a list of changes which were separated
  by newline.
  """
  def split_by_newline(buffer, chunk) when is_binary(buffer) and is_binary(chunk) do
    # don't trim, we use the "" to identify the end of the chunk
    case (buffer <> chunk) |> String.split("\n") |> Enum.reverse() do
      # no changes, so just append to the buffer
      [buffer | []] -> {buffer, []}
      # one or more changes, return
      [head | tail] -> {head, Enum.reverse(tail)}
    end
  end

  # we have received one or more complete changes from CouchDB, `{"seq":"..}`
  # the accumulator of changes has been completed
  @impl true
  def handle_continue({:changes, []}, state) do
    {:noreply, state}
  end

  # heartbeats come through as empty messages
  @impl true
  def handle_continue({:changes, ["" | changes]}, state) do
    debug(:heartbeat)
    {:noreply, state, {:continue, {:changes, changes}}}
  end

  # handle possibly nested changes by sending another continue
  @impl true
  def handle_continue({:changes, [<<"{\"seq\":\"", _rest::binary>> = change | changes]}, state) do
    case Jason.decode(change) do
      {:ok, json} -> debug(doc: json["id"], seq: json["seq"])
      _ -> debug(bad_json: change)
    end

    {:noreply, state, {:continue, {:changes, changes}}}
  end

  @impl true
  def handle_continue({:changes, change}, state) do
    debug(wtf: change)
    {:noreply, state}
  end

  # GenServer Client API

  @doc """
  Start GenServer
  """

  def start(url \\ @changes_uri, opts \\ %{}) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [url, opts])
  end

  # Internal Helpers

  @doc """
  Prepares a CouchDB connection and verifies you have
  sufficient permissions to access the database.

  ## Examples

  iex> Bowie.connect(
    "http://admin:passwd@127.0.0.1:5984/_users",
    since: :now,
    include_docs: true,
    heartbeat: 45_000,
    :inet6)
  {:ok, %Bowie{}}
  """

  def connect(url \\ @changes_uri, _opts \\ %{}) do
    uri = URI.parse(url)
    # TODO explode opts
    # merge over defaults
    # flatten query string and append to uri path

    # because erlang
    host = String.to_charlist(uri.host)
    # headers contain authenticaion data which we want to be illegible in
    # stack traces. instead we make a fun, and pass that around instead.
    headers = fn -> [{"authorization", "Basic " <> Base.encode64(uri.userinfo)}] end

    {:ok, pid} = :gun.open(host, uri.port, @couch_inet6)
    {:ok, protocol} = :gun.await_up(pid)

    feed = String.to_charlist(uri.path <> "?" <> uri.query)
    ref = :gun.get(pid, feed, headers.())

    {:ok,
     %__MODULE__{
       protocol: protocol,
       host: host,
       port: uri.port,
       feed: feed,
       headers_fun: headers,
       options: @couch_inet6,
       gun_pid: pid,
       gun_ref: ref
     }}
  end

  @highlighting [number: :yellow, atom: :cyan, string: :green, nil: :magenta, boolean: :magenta]
  def debug(any) do
    IO.inspect(any,
      label: __MODULE__,
      syntax_colors: @highlighting,
      width: 0,
      limit: :infinity,
      printable_limit: :infinity
    )
  end
end
