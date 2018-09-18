defmodule BowieTest do
  use ExUnit.Case

  setup do
    bypass = Bypass.open(port: 5984)
    {:ok, bypass: bypass}
  end

  doctest Bowie

  defp db(),
    do: %ICouch.DB{
      name: "_users",
      server: %ICouch.Server{
        direct: nil,
        ib_options: [basic_auth: {'admin', 'passwd'}],
        timeout: nil,
        uri: %URI{
          authority: "127.0.0.1",
          fragment: nil,
          host: "127.0.0.1",
          path: "/",
          port: 5984,
          query: nil,
          scheme: "http",
          userinfo: nil
        }
      }
    }

  test "makes a couch db handle correctly", %{bypass: bypass} do
    Bypass.expect_once(bypass, "HEAD", "/_users/", fn conn ->
      Plug.Conn.resp(conn, 200, "")
    end)

    assert Bowie.db("_users") == db()
  end

  test "defines child_spec/1" do
    assert Bowie.child_spec([]) == %{
             id: Bowie,
             restart: :permanent,
             shutdown: 500,
             start: {Bowie, :start_link, []},
             type: :worker
           }
  end

end
