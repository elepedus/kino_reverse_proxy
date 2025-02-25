defmodule KinoReverseProxy do
  @moduledoc """
  A module for creating reverse proxies for Kino applications in Livebook.

  KinoReverseProxy allows Livebook apps to be accessed on their own domains.
  It is deployed as a Livebook app, listens for web traffic on an arbitrary port,
  and provides host-based routing to other deployed Livebook apps using either
  their Kino.Proxy URL or their port for standalone server processes.
  """

  @doc """
  Creates and starts a reverse proxy server for a Kino application.

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
  end
end
