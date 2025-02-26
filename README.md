# KinoReverseProxy

KinoReverseProxy allows Livebook apps to be accessed on their own domains. It is deployed as a Livebook app, listens for web traffic on an arbitrary port, and provides host-based routing to other deployed Livebook apps using either their Kino.Proxy URL or their port for standalone server processes.

## Installation

Add `kino_reverse_proxy` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kino_reverse_proxy, "~> 0.1.0"},
    {:bandit, "~> 2.0"}
  ]
end
```

## Usage

### Basic Usage

```elixir
# Proxy an application from speedrun.dev to localhost:5555
KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser")
```

### Custom Port

```elixir
# Proxy an application from speedrun.dev to localhost:8080
KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser", port: 8080)
```

### Custom Timeout

```elixir
# Set a custom timeout of 60 seconds
KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser", timeout: 60_000)
```

### Using HTTPS

```elixir
# Use HTTPS for the proxy server
KinoReverseProxy.proxy("https://speedrun.dev/proxy/apps/time-guesser", scheme: :https)
```

### Host-Based Routing for Multiple Applications

You can proxy multiple applications using host-based routing:

```elixir
# Basic host-based routing
KinoReverseProxy.proxy_hosts(%{
  "app1.example.com" => "https://speedrun.dev/proxy/apps/app1",
  "app2.example.com" => "https://speedrun.dev/proxy/apps/app2"
})

# With custom port and default URL for unknown hosts
KinoReverseProxy.proxy_hosts(
  %{
    "app1.example.com" => "https://speedrun.dev/proxy/apps/app1",
    "app2.example.com" => "https://speedrun.dev/proxy/apps/app2"
  },
  port: 8080,
  default_url: "https://speedrun.dev/proxy/apps/default-app"
)
```

## Manual Configuration

If you need more control over the proxy configuration, you can create your own Bandit server with ReverseProxyPlug:

```elixir
webserver =
  {Bandit,
   plug: {
     ReverseProxyPlug,
     upstream: fn
       %{path_info: []} ->
         "https://speedrun.dev/proxy/apps/time-guesser"

       %{path_info: ["proxy", "apps", "time-guesser" | _]} ->
         "https://speedrun.dev/"
     end,
     client_options: [
       timeout: 30000,
       recv_timeout: 30000,
       hackney: [
         timeout: 30000,
         recv_timeout: 30000,
         pool: :default
       ]
     ]
   },
   scheme: :http,
   thousand_island_options: [
     read_timeout: 30_000
   ],
   port: 5555}

Kino.start_child!(webserver)
```

