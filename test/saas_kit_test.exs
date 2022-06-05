defmodule SaasKitTest do
  use ExUnit.Case
  doctest SaasKit

  test "greets the world" do
    assert SaasKit.hello() == :world
  end
end
