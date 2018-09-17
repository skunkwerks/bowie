defmodule BowieTest do
  use ExUnit.Case
  doctest Bowie

  test "greets the world" do
    assert Bowie.hello() == :world
  end
end
