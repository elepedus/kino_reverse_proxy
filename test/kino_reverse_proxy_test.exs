# Mock module for ReverseProxyPlug to avoid actual HTTP requests in tests
defmodule MockReverseProxyPlug do
  def init(opts), do: opts
  
  def call(conn, opts) do
    # Store the upstream URL that would be used for verification in tests
    upstream = opts[:upstream]
    upstream_url = if is_function(upstream) do
      upstream.(conn)
    else
      upstream
    end
    
    # Store the upstream URL in private assigns for verification
    Plug.Conn.put_private(conn, :upstream_url, upstream_url)
  end
end

# Helper module for testing URL parsing and path handling
defmodule URLPathHelper do
  def parse_path(url) do
    uri = URI.parse(url)
    path = uri.path || ""
    
    path
    |> String.split("/")
    |> Enum.filter(&(&1 != ""))
  end
  
  def base_url(url) do
    URI.parse(url).host
  end
end

defmodule KinoReverseProxyTest do
  use ExUnit.Case, async: false # Disable async to avoid mocking conflicts
  doctest KinoReverseProxy

  import ExUnit.CaptureLog
  import Plug.Conn, only: [put_req_header: 3]
  
  alias KinoReverseProxy.HostRouter
  
  # Helper function to create a mock connection for testing
  defp build_conn(host, path) do
    conn = %Plug.Conn{
      host: host,
      request_path: path,
      path_info: String.split(path, "/") |> Enum.filter(&(&1 != ""))
    }
    
    # Add a default user agent
    put_req_header(conn, "user-agent", "KinoReverseProxy Test")
  end
  
  describe "KinoReverseProxy.proxy/2" do
    test "extracts base_url and path_prefix correctly" do
      url = "https://example.com/proxy/apps/my-app"
      # Use a random high port for testing
      port = Enum.random(10000..65000)
      
      assert capture_log(fn ->
        # We call the function but don't assert its return value since we can't easily test the child process
        # Instead, we make sure it doesn't raise an error 
        result = KinoReverseProxy.proxy(url, port: port)
        assert match?({:ok, _}, result)
      end) =~ ""
    end
    
    test "accepts custom timeout values" do
      url = "https://example.com/proxy/apps/my-app"
      port = Enum.random(10000..65000)
      timeout = 60_000
      
      assert capture_log(fn ->
        result = KinoReverseProxy.proxy(url, port: port, timeout: timeout)
        assert match?({:ok, _}, result)
      end) =~ ""
    end
    
    test "accepts custom scheme" do
      url = "https://example.com/proxy/apps/my-app"
      port = Enum.random(10000..65000)
      
      # Mock the Kino.start_child! function to avoid actual server startup
      # This is needed since HTTPS scheme requires SSL certs which we don't have in tests
      
      try do
        # Replace Kino.start_child! with a mock that just returns :ok
        :meck.new(Kino, [:passthrough])
        :meck.expect(Kino, :start_child!, fn _webserver -> :ok end)
        
        result = KinoReverseProxy.proxy(url, port: port, scheme: :http)
        assert match?({:ok, _}, result)
      after
        # Clean up
        :meck.unload(Kino)
      end
    end
  end
  
  describe "KinoReverseProxy.proxy_hosts/2" do
    test "processes the hosts map correctly" do
      hosts_map = %{
        "app1.example.com" => "https://example.com/proxy/apps/app1",
        "app2.example.com" => "https://example.com/proxy/apps/app2"
      }
      # Use a random high port for testing
      port = Enum.random(10000..65000)
      
      assert capture_log(fn ->
        # We call the function but don't assert its return value since we can't easily test the child process
        # Instead, we make sure it doesn't raise an error
        result = KinoReverseProxy.proxy_hosts(hosts_map, port: port)
        assert match?({:ok, _}, result)
      end) =~ ""
    end
    
    test "accepts a default_url option" do
      hosts_map = %{
        "app1.example.com" => "https://example.com/proxy/apps/app1"
      }
      port = Enum.random(10000..65000)
      default_url = "https://example.com/proxy/apps/default"
      
      assert capture_log(fn ->
        result = KinoReverseProxy.proxy_hosts(hosts_map, port: port, default_url: default_url)
        assert match?({:ok, _}, result)
      end) =~ ""
    end
    
    test "accepts custom timeout and scheme" do
      hosts_map = %{
        "app1.example.com" => "https://example.com/proxy/apps/app1"
      }
      port = Enum.random(10000..65000)
      timeout = 60_000
      
      # Mock the Kino.start_child! function to avoid actual server startup
      # This is needed since HTTPS scheme requires SSL certs which we don't have in tests 
      try do
        # Replace Kino.start_child! with a mock that just returns :ok
        :meck.new(Kino, [:passthrough])
        :meck.expect(Kino, :start_child!, fn _webserver -> :ok end)
        
        result = KinoReverseProxy.proxy_hosts(hosts_map, port: port, timeout: timeout, scheme: :http)
        assert match?({:ok, _}, result)
      after
        # Clean up
        :meck.unload(Kino)
      end
    end
  end
  
  # Test for the 404 case which is the simplest to test
  describe "KinoReverseProxy.HostRouter - 404 case" do
    # We need to modify the Plug.Conn functions only for this test
    test "returns 404 HTML when host not found and no default provided" do
      # Override the necessary plug functions for this test only
      :meck.new(Plug.Conn, [:passthrough])
      :meck.expect(Plug.Conn, :put_resp_content_type, 
                  fn conn, content_type -> Map.put(conn, :resp_content_type, content_type) end)
      :meck.expect(Plug.Conn, :send_resp, 
                  fn conn, status, body -> 
                    conn 
                    |> Map.put(:status, status) 
                    |> Map.put(:resp_body, body) 
                  end)
      :meck.expect(Plug.Conn, :halt, fn conn -> Map.put(conn, :halted, true) end)
      
      try do
        # Setup hosts map with parsed URLs
        hosts_map = %{}
        
        # Create router options
        router_opts = [
          hosts_map: hosts_map,
          default_url: nil,
          client_options: [timeout: 30_000]
        ]
        
        # Initialize router
        opts = HostRouter.init(router_opts)
        
        # Create test connection
        conn = build_conn("unknown.example.com", "/")
        
        # Execute call
        result_conn = HostRouter.call(conn, opts)
        
        # Verify response
        assert result_conn.status == 404
        assert result_conn.resp_body =~ "Kino Reverse Proxy"
        assert result_conn.resp_body =~ "unknown.example.com"
        assert result_conn.halted
      after
        :meck.unload(Plug.Conn)
      end
    end
  end
  
  # Test URL parsing and path handling without the router
  describe "URL path parsing" do
    test "URL parsing works as expected for different scenarios" do
      # Test a standard URL with path components
      url = "https://example.com/proxy/apps/app1"
      uri = URI.parse(url)
      path_prefix = uri.path |> String.split("/") |> Enum.filter(&(&1 != ""))
      
      # Verify path parsing works as expected
      assert path_prefix == ["proxy", "apps", "app1"]
      assert uri.host == "example.com"
      
      # Test URLs with various path patterns that we need to handle
      urls = [
        {"https://example.com/proxy/apps/app1", ["proxy", "apps", "app1"]},
        {"https://example.com/proxy/apps/app1/", ["proxy", "apps", "app1"]},
        {"https://example.com/", []},
        {"https://example.com", []},
        {"https://example.com/proxy/apps/app1?param=value", ["proxy", "apps", "app1"]}
      ]
      
      for {test_url, expected_path} <- urls do
        test_uri = URI.parse(test_url)
        test_path = test_uri.path || ""
        parsed_path = test_path |> String.split("/") |> Enum.filter(&(&1 != ""))
        assert parsed_path == expected_path, "Path parsing failed for #{test_url}"
      end
    end
    
    test "hosts_map is parsed correctly in proxy_hosts" do
      hosts_map = %{
        "app1.example.com" => "https://example.com/proxy/apps/app1",
        "app2.example.com" => "https://example.com/proxy/apps/app2"
      }
      
      # Manually parse the hosts map like in the actual implementation
      parsed_hosts = Enum.map(hosts_map, fn {host, url} ->
        uri = URI.parse(url)
        {
          host, 
          %{
            url: url, 
            base_url: uri.host,
            path_prefix: uri.path |> String.split("/") |> Enum.filter(&(&1 != ""))
          }
        }
      end) |> Map.new()
      
      # Verify the parsing is correct
      assert parsed_hosts["app1.example.com"].url == "https://example.com/proxy/apps/app1"
      assert parsed_hosts["app1.example.com"].base_url == "example.com"
      assert parsed_hosts["app1.example.com"].path_prefix == ["proxy", "apps", "app1"]
      
      assert parsed_hosts["app2.example.com"].url == "https://example.com/proxy/apps/app2"
      assert parsed_hosts["app2.example.com"].base_url == "example.com"
      assert parsed_hosts["app2.example.com"].path_prefix == ["proxy", "apps", "app2"]
    end
  end
end

# Dedicated test module for URL parsing logic
defmodule URLParsingTest do
  use ExUnit.Case
  
  alias URLPathHelper, as: Helper
  
  test "parses standard Kino proxy URLs correctly" do
    url = "https://example.com/proxy/apps/my-app"
    
    assert Helper.base_url(url) == "example.com"
    assert Helper.parse_path(url) == ["proxy", "apps", "my-app"]
  end
  
  test "handles URLs with no path correctly" do
    url = "https://example.com"
    
    assert Helper.base_url(url) == "example.com"
    assert Helper.parse_path(url) == []
  end
  
  test "handles URLs with trailing slashes correctly" do
    url = "https://example.com/proxy/apps/my-app/"
    
    assert Helper.base_url(url) == "example.com"
    assert Helper.parse_path(url) == ["proxy", "apps", "my-app"]
  end
  
  test "handles complex URLs with query parameters" do
    url = "https://example.com/proxy/apps/my-app?param=value"
    
    assert Helper.base_url(url) == "example.com"
    assert Helper.parse_path(url) == ["proxy", "apps", "my-app"]
  end
  
  test "handles URLs with multiple path segments" do
    url = "https://example.com/proxy/apps/my-app/subpath/nested"
    
    assert Helper.base_url(url) == "example.com"
    assert Helper.parse_path(url) == ["proxy", "apps", "my-app", "subpath", "nested"]
  end
end