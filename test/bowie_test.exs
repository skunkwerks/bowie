defmodule BowieTest do
  use ExUnit.Case, async: true
  import Bowie

  # setup do
  #   bypass = Bypass.open(port: 5984)
  #   {:ok, bypass: bypass}
  # end

  test "partial buffer is returned as buffer",
    do: assert(split_by_newline("abc", "") == {"abc", []})

  test "buffer and chunk with changes returns changes in correct order",
    do: assert(split_by_newline("abc", "\ndef\n123") == {"123", ["abc", "def"]})

  test "incomplete chunk is appended to buffer",
    do: assert(split_by_newline("123", "456") == {"123456", []})

  # assert split_by_newline("def", "") == {"def", []}
  # assert split_by_newline("abc", "\ndef\nghi") == {"ghi", ["abc", "def"]}
  # end

  #   assert Bowie.db("_users") == db()
  # end

  # doctest Bowie

  # defp db(),
  #   do: %ICouch.DB{
  #     name: "_users",
  #     server: %ICouch.Server{
  #       direct: nil,
  #       ib_options: [basic_auth: {'admin', 'passwd'}],
  #       timeout: nil,
  #       uri: %URI{
  #         authority: "127.0.0.1",
  #         fragment: nil,
  #         host: "127.0.0.1",
  #         path: "/",
  #         port: 5984,
  #         query: nil,
  #         scheme: "http",
  #         userinfo: nil
  #       }
  #     }
  #   }

  # test "makes a couch db handle correctly", %{bypass: bypass} do
  #   Bypass.expect_once(bypass, "HEAD", "/_users/", fn conn ->
  #     Plug.Conn.resp(conn, 200, "")
  #   end)

  #   assert Bowie.db("_users") == db()
  # end

  # test "defines child_spec/1" do
  #   assert Bowie.child_spec([]) == %{
  #            id: Bowie,
  #            restart: :permanent,
  #            shutdown: 500,
  #            start: {Bowie, :start_link, []},
  #            type: :worker
  #          }
  # end

  # test "invokes init/2 callback" do
  #   Application.put_env(:bowie, __MODULE__.InitBowie, parent: self())

  #   defmodule InitBowie do
  #     use Phoenix.Bowie, otp_app: :bowie

  #     def init(:supervisor, opts) do
  #       send(opts[:parent], {self(), :sample})
  #       {:ok, opts}
  #     end
  #   end

  #   {:ok, pid} = InitBowie.start_link()
  #   assert_receive {^pid, :sample}
  # end
end
