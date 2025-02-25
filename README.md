# KinoReverseProxy

KinoReverseProxy allows Livebook apps to be accessed on their own domains. It is deployed as a Livebook app, listens for web traffic on an arbitrary port, and provides host-based routing to other deployed Livebook apps using either their Kino.Proxy URL or their port for standalone server processes.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `kino_reverse_proxy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:kino_reverse_proxy, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/kino_reverse_proxy>.

