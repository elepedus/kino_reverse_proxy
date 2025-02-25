defmodule KinoReverseProxyTest do
  use ExUnit.Case
  doctest KinoReverseProxy

  test "greets the world" do
    assert KinoReverseProxy.hello() == :world
  end
end
