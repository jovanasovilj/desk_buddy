defmodule DeskBuddyTest do
  use ExUnit.Case
  doctest DeskBuddy

  test "greets the world" do
    assert DeskBuddy.hello() == :world
  end
end
