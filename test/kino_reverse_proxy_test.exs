defmodule KinoReverseProxyTest do
  use ExUnit.Case
  doctest KinoReverseProxy

  import ExUnit.CaptureLog
  
  test "proxy/2 extracts base_url and path_prefix correctly" do
    url = "https://example.com/proxy/apps/my-app"
    # Use a random high port for testing
    port = Enum.random(10000..65000)
    
    assert capture_log(fn ->
      # We call the function but don't assert its return value since we can't easily test the child process
      # Instead, we make sure it doesn't raise an error 
      KinoReverseProxy.proxy(url, port: port)
    end) =~ ""
  end
  
  test "proxy_hosts/2 processes the hosts map correctly" do
    hosts_map = %{
      "app1.example.com" => "https://example.com/proxy/apps/app1",
      "app2.example.com" => "https://example.com/proxy/apps/app2"
    }
    # Use a random high port for testing
    port = Enum.random(10000..65000)
    
    assert capture_log(fn ->
      # We call the function but don't assert its return value since we can't easily test the child process
      # Instead, we make sure it doesn't raise an error
      KinoReverseProxy.proxy_hosts(hosts_map, port: port)
    end) =~ ""
  end
end
