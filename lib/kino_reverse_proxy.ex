defmodule KinoReverseProxy.HostRouter do
  @moduledoc """
  A router module that handles host-based routing for the reverse proxy.
  """
  use Plug.Router
  
  plug :match
  plug :dispatch
  
  # These fields will be set by the main module
  def init(opts), do: opts
  
  # This will be overridden at runtime
  def call(conn, opts) do
    hosts_map = opts[:hosts_map]
    default_url = opts[:default_url]
    
    # Check if the host is in our map
    case Map.get(hosts_map, conn.host) do
      # Host found, create a ReverseProxyPlug for this host
      %{url: url, base_url: base_url, path_prefix: path_prefix} ->
        # Handle path prefixing like in the original implementation
        upstream = fn conn ->
          case conn.path_info do
            [] -> 
              url
            ^path_prefix -> 
              "https://#{base_url}/"
            path ->
              if List.starts_with?(path, path_prefix) do
                "https://#{base_url}/"
              else
                url
              end
          end
        end
        
        proxy_opts = [
          upstream: upstream,
          client_options: opts[:client_options]
        ]
        ReverseProxyPlug.call(conn, ReverseProxyPlug.init(proxy_opts))
        
      # Host not found but default URL is provided
      nil when not is_nil(default_url) ->
        # Parse the default URL to handle paths correctly
        default_uri = URI.parse(default_url)
        default_path_prefix = default_uri.path |> String.split("/") |> Enum.filter(&(&1 != ""))
        
        # Use the same path handling logic for consistency
        upstream = fn conn ->
          case conn.path_info do
            [] -> 
              default_url
            ^default_path_prefix -> 
              "https://#{default_uri.host}/"
            path ->
              if List.starts_with?(path, default_path_prefix) do
                "https://#{default_uri.host}/"
              else
                default_url
              end
          end
        end
        
        proxy_opts = [
          upstream: upstream,
          client_options: opts[:client_options]
        ]
        ReverseProxyPlug.call(conn, ReverseProxyPlug.init(proxy_opts))
        
      # Host not found, show a nice error page
      nil ->
        html = """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Kino Reverse Proxy</title>
          <style>
            body { font-family: system-ui, -apple-system, sans-serif; padding: 2rem; max-width: 800px; margin: 0 auto; line-height: 1.5; }
            h1 { color: #4b5563; }
            .message { background-color: #f3f4f6; padding: 1rem; border-radius: 0.375rem; }
          </style>
        </head>
        <body>
          <h1>Kino Reverse Proxy</h1>
          <p>The reverse proxy server is running correctly.</p>
          <div class="message">
            <p>The requested host <code>#{conn.host}</code> is not configured in this proxy.</p>
          </div>
        </body>
        </html>
        """
        
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(404, html)
        |> halt()
    end
  end
  
  # Default catch-all route
  match _ do
    send_resp(conn, 404, "Not found")
  end
end

defmodule KinoReverseProxy do
  @moduledoc """
  A module for creating reverse proxies for Kino applications in Livebook.

  KinoReverseProxy allows Livebook apps to be accessed on their own domains.
  It is deployed as a Livebook app, listens for web traffic on an arbitrary port,
  and provides host-based routing to other deployed Livebook apps using either
  their Kino.Proxy URL or their port for standalone server processes.
  """

  @doc """
  Creates and starts a reverse proxy server for a single Kino application.

  ## Parameters
  
  * `url` - The URL of the Kino application to proxy
  * `options` - Additional options for the proxy server:
    * `:port` - The port to listen on (default: 5555)
    * `:timeout` - The timeout in milliseconds (default: 36000)
    * `:scheme` - The HTTP scheme to use (default: :http)

  ## Examples

      # Basic usage
      KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser")
      
      # With custom port
      KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser", port: 8080)
      
  """
  def proxy(url, options \\ []) do
    port = Keyword.get(options, :port, 5555)
    timeout = Keyword.get(options, :timeout, 36_000)
    scheme = Keyword.get(options, :scheme, :http)
    
    base_url = URI.parse(url).host
    path_prefix = URI.parse(url).path |> String.split("/") |> Enum.filter(&(&1 != ""))
    
    webserver =
      {Bandit,
       plug: {
         ReverseProxyPlug,
         upstream: fn
           %{path_info: []} ->
             url

           %{path_info: ^path_prefix} ->
             "https://#{base_url}/"
           
           %{path_info: path} ->
             if List.starts_with?(path, path_prefix) do
               "https://#{base_url}/"
             else
               url
             end
             
           _ ->
             url
         end,
         client_options: [
           timeout: timeout,
           recv_timeout: timeout,
           hackney: [
             timeout: timeout,
             recv_timeout: timeout,
             pool: :default
           ]
         ]
       },
       scheme: scheme,
       thousand_island_options: [
         read_timeout: timeout
       ],
       port: port}

    Kino.start_child!(webserver)
    {:ok, webserver}
  end

  @doc """
  Creates and starts a reverse proxy server with host-based routing to multiple Kino applications.

  ## Parameters
  
  * `hosts_map` - A map of hostnames to URLs, where each key is a hostname and each value is the URL to proxy for that host
  * `options` - Additional options for the proxy server:
    * `:port` - The port to listen on (default: 5555)
    * `:timeout` - The timeout in milliseconds (default: 36000)
    * `:scheme` - The HTTP scheme to use (default: :http)
    * `:default_url` - An optional default URL to route to when the host doesn't match any in the hosts_map

  ## Examples

      # Basic host-based routing
      KinoReverseProxy.proxy_hosts(%{
        "app1.example.com" => "https://speedrun.dev/proxy/apps/time-guesser",
        "app2.example.com" => "https://speedrun.dev/proxy/apps/different-app"
      })
      
      # With custom port and default URL
      KinoReverseProxy.proxy_hosts(
        %{
          "app1.example.com" => "https://speedrun.dev/proxy/apps/time-guesser",
          "app2.example.com" => "https://speedrun.dev/proxy/apps/different-app"
        },
        port: 8080,
        default_url: "https://speedrun.dev/proxy/apps/default-app"
      )
      
  """
  def proxy_hosts(hosts_map, options \\ []) when is_map(hosts_map) do
    port = Keyword.get(options, :port, 5555)
    timeout = Keyword.get(options, :timeout, 36_000)
    scheme = Keyword.get(options, :scheme, :http)
    default_url = Keyword.get(options, :default_url)
    
    # Parse the URLs in advance for efficiency
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
    
    # Create client options for the proxy
    client_options = [
      timeout: timeout,
      recv_timeout: timeout,
      hackney: [
        timeout: timeout,
        recv_timeout: timeout,
        pool: :default
      ]
    ]
    
    # Configure our host router
    router_opts = [
      hosts_map: parsed_hosts,
      default_url: default_url,
      client_options: client_options
    ]
    
    webserver =
      {Bandit,
       plug: {KinoReverseProxy.HostRouter, router_opts},
       scheme: scheme,
       thousand_island_options: [
         read_timeout: timeout
       ],
       port: port}

    Kino.start_child!(webserver)
    {:ok, webserver}
  end
end
