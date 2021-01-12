# Copyright (c) 2017 MeetNow! GmbH
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

  defstruct [:conn, :db, :query, :headers, :last_seq, requests: %{}]

  # hopefully you are only using this while testing
  @couch_uri "http://admin:passwd@localhost:5984/"
  @couch_db "_users"
  @couch_changes "/_changes?feed=continuous&heartbeat=45000&include_docs=true&since=now"
  @couch_transport transport_opts: [{:inet6, true}]
  @changes_uri @couch_uri <> @couch_db <> @couch_changes
  @doc """
  Prepares a CouchDB connection and verifies you have
  sufficient permissions to access the database.

  ## Examples

  Bowie.connect!("http://admin:passwd@127.0.0.1:5984/_users")

  """

  def connect!(uri \\ @changes_uri) do
    uri = URI.parse(uri)
    [db, "_changes"] = String.split(uri.path, "/", trim: true)
    basic_auth = {"authorization", "Basic " <> Base.encode64(uri.userinfo)}
    headers = [basic_auth]

    {:ok, pid} =
      start_link(
        {String.to_existing_atom(uri.scheme), uri.host, uri.port, db, uri.query, headers}
      )

    pid
  end

  def start_link({scheme, host, port, db, query, headers}) do
    GenServer.start_link(__MODULE__, {scheme, host, port, db, query, headers})
  end

  def changes(pid) do
    GenServer.cast(pid, {:changes})
  end

  def request(pid, method \\ "GET", path, headers \\ [], body \\ nil) do
    GenServer.call(pid, {:request, method, path, headers, body})
  end

  @highlighting [number: :yellow, atom: :cyan, string: :green, nil: :magenta, boolean: :magenta]
  def debug(any) do
    IO.inspect(any, label: __MODULE__, syntax_colors: @highlighting, width: 0)
  end

  ## Callbacks

  @impl true
  def init({scheme, host, port, db, query, headers}) do
    case Mint.HTTP.connect(scheme, host, port, @couch_transport) do
      {:ok, conn} ->
        conn = Mint.HTTP.put_private(conn, :client_name, "Bowie")
        state = %__MODULE__{conn: conn, db: db, query: query, headers: headers}
        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

#   @impl true
#   def handle_cast({:changes}, from, state) do
#     Logger.debug("got #{inspect(state)}")
#     # In both the successful case and the error case, we make sure to update the connection
#     # struct in the state since the connection is an immutable data structure.
#     path = "/" <> state.db <> "/_changes?" <> state.query

#     case Mint.HTTP.request(state.conn, "GET", path, state.headers, nil) do
#       {:ok, conn, request_ref} ->
#         state = put_in(state.conn, conn)
#         # We store the caller this request belongs to and an empty map as the response.
#         # The map will be filled with status code, headers, and so on.
#         state = put_in(state.requests[request_ref], %{from: from, response: %{}})
#         {:noreply, state}

#       {:error, conn, reason} ->
#         state = put_in(state.conn, conn)
#         {:reply, {:error, reason}, state}
#     end
#   end

  @impl true
  def handle_call({:request, method, path, headers, body}, from, state) do
    # In both the successful case and the error case, we make sure to update the connection
    # struct in the state since the connection is an immutable data structure.
    case Mint.HTTP.request(state.conn, method, path, headers, body) do
      {:ok, conn, request_ref} ->
        state = put_in(state.conn, conn)
        # We store the caller this request belongs to and an empty map as the response.
        # The map will be filled with status code, headers, and so on.
        state = put_in(state.requests[request_ref], %{from: from, response: %{}})
        {:noreply, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
 def handle_cast({:changes}, state) do
    Logger.debug("got #{inspect(state)}")
    {:noreply, state}
    # In both the successful case and the error case, we make sure to update the connection
    # struct in the state since the connection is an immutable data structure.
    # path = "/" <> state.db <> "/_changes?" <> state.query

    # case Mint.HTTP.request(state.conn, "GET", path, state.headers, nil) do
    #   {:ok, conn, request_ref} ->
    #     state = put_in(state.conn, conn)
    #     # We store the caller this request belongs to and an empty map as the response.
    #     # The map will be filled with status code, headers, and so on.
    #     state = put_in(state.requests[request_ref], %{from: from, response: %{}})
    #     {:noreply, state}

    #   {:error, conn, reason} ->
    #     state = put_in(state.conn, conn)
    #     {:reply, {:error, reason}, state}
    # end
  end

  @impl true
  def handle_info(message, state) do
    # We should handle the error case here as well, but we're omitting it for brevity.
    case Mint.HTTP.stream(state.conn, message) do
      :unknown ->
        _ = Logger.error(fn -> "Received unknown message: " <> inspect(message) end)
        {:noreply, state}

      {:ok, conn, responses} ->
        state = put_in(state.conn, conn)
        state = Enum.reduce(responses, state, &process_response/2)
        {:noreply, state}
    end
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, headers}, state) do
    put_in(state.requests[request_ref].response[:headers], headers)
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(state.requests[request_ref].response[:data], fn data -> (data || "") <> new_data end)
  end

  # When the request is done, we use GenServer.reply/2 to reply to the caller that was
  # blocked waiting on this request.
  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])
    GenServer.reply(from, {:ok, response})
    state
  end

  # A request can also error, but we're not handling the erroneous responses for
  # brevity.
end

# def changes({conn, ref}) do
#   receive do
#     message ->
#       case Mint.HTTP.stream(conn, message) do
#         :unknown -> handle_message(message, ref)
#         {:ok, conn, responses} -> handle_responses(conn, responses, ref)
#       end
#   end
#   {conn, ref}
# end

# def handle_message(message, _ref) do
#   Logger.debug("msg: #{message}")
#   :ok
# end

# def handle_responses(_conn, [], _ref) do
#   Logger.debug("responses: DONE")
#   :ok
# end

# def handle_responses(conn, [response | tail], ref) do
#   handle_response(conn,response, ref)
#   handle_responses(conn,tail, ref)
# end

# def handle_response(conn, {:status, ref, status}, ref) do
#   Logger.debug("status: #{status}")
#   {conn, ref}
# end

# def handle_response(conn, {:headers, ref, headers}, ref) do
#   Logger.debug("headers: #{inspect(headers)}")
#   {conn, ref}
# end

# def handle_response(conn, {:data, ref, chunk}, ref) do
#   Logger.debug("chunk: #{chunk}")
#   {conn, ref}
# end

# @doc """
# Starts an unsupervised worker. Use `start_link/1` for a supervised connection.

# ## Examples

#     > Bowie.db("http://admin:passwd@127.0.0.1:5984/", "_users") |> Bowie.start(since: 3)
#       [debug] ICouch request: [head] http://127.0.0.1:5984/_users/
#       [debug] Bowie changes listener #PID<0.436.0> started since 3.
#       [debug] ICouch request: [get] http://127.0.0.1:5984/_users/_changes?feed=continuous&heartbeat=60000&since=3&timeout=7200000
#       [info] Started stream
#       [debug] Received changes for: ["org.couchdb.user:jan"]
#     Elixir.Bowie: %{
#       "changes" => [
#         %{
#           "rev" => "2-448ce420d5fd53b7202f695d009b9265"
#         }
#       ],
#       "deleted" => true,
#       "id" => "org.couchdb.user:jan",
#       "seq" => 5
#     }
#     {:ok, #PID<0.436.0>}

# """

# def start(db, opts \\ [include_docs: true]) do
#   GenServer.start(__MODULE__, [db, opts])
# end

## GenServery

#   use GenServer
#   require Logger

#   @doc """
#   Starts an OTP supervised worker as part of a larger supervision tree:

#   ## Examples

#       couch = "http://admin:passwd@127.0.0.1:5984/"
#       db = Bowie.db(couch, "_users")
#       flags = [include_docs: true]
#       args = [db, flags]
#       workers = [%{id: My.Worker, start: {Bowie, :start_link, args}}]
#       options = [strategy: :one_for_one, name: My.Supervisor]
#       Supervisor.start_link( workers, options )
#   """
#   def start_link(db, opts \\ [], gen_opts \\ []) do
#     GenServer.start_link(__MODULE__, [db, opts], gen_opts)
#   end

#   def child_spec(opts) do
#     # the only difference to the typical Supervisor.child_spec/1 is
#     # that Bowie doesn't wrap the opts in list before passing them on.
#     %{
#       id: __MODULE__,
#       start: {__MODULE__, :start_link, opts},
#       type: :worker,
#       restart: :permanent,
#       shutdown: 500
#     }
#   end

#   ## Callbacks
#   @callback handle_change(any, pid) :: {:ok, pid}
#   def handle_change(change, pid) do
#     Bowie.debug({pid, change})
#   end

#   @impl true
#   def init([db, opts]) do
#     {seq, _opts} = Keyword.pop(opts, :since)

#     Logger.debug(
#       "Bowie changes listener #{inspect(self())} started" <>
#         "#{if seq == nil, do: "", else: " since "}#{if seq != nil, do: seq, else: ""}."
#     )

#     {:ok, _} = Bowie.Changes.start_link(db, opts)
#   end
# end

# defmodule Bowie.Changes do
#   @moduledoc """
#   Supporting module for Bowie to provide a separate mailbox queue for
#   received changes independent of the ibrowse worker that does the
#   actual work. This is the functionality you override with your own
#   handle_change functionality.
#   """

#   # use ChangesFollower

#   def start_link(db, opts) do
#     # ChangesFollower.start_link(__MODULE__, [db, opts, self()])
#   end

#   def init([db, opts, pid]),
#     do: {:ok, db, opts, pid}

#   def handle_change(change, pid) do
#     Bowie.debug(change)
#     {:ok, pid}
#   end
