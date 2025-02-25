# CLAUDE.md - Guide for Claude on KinoReverseProxy

## Project Purpose
KinoReverseProxy allows Livebook apps to be accessed on their own domains. It is deployed as a Livebook app, listens for web traffic on an arbitrary port, and provides host-based routing to other deployed Livebook apps using either their Kino.Proxy URL or their port for standalone server processes.

## Build and Test Commands
- Build project: `mix compile`
- Run all tests: `mix test`
- Run a specific test: `mix test test/file_name_test.exs:line_number`
- Run with specific test pattern: `mix test --only tag_name`
- Interactive shell: `iex -S mix`
- Dependency management: `mix deps.get`

## Code Style Guidelines
- Use 2-space indentation
- Module names are CamelCase, function names are snake_case
- Functions should have @doc comments in Markdown format
- Use @moduledoc to document modules
- Prefer pattern matching over conditionals where possible
- Log important events with appropriate log levels
- Implement behaviors explicitly (e.g., `@behaviour Plug`)
- Prefer pipeline operator |> for multi-step transformations
- Use specific imports (`import Plug.Conn` rather than `import Plug`)
- Error handling: log errors and return appropriate HTTP status codes
- Function specs should be included for public API functions