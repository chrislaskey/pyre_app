# Pyre App

A a fully configured standlone application running the [Pyre ecosystem](https://github.com/chrislaskey/pyre).

## Installation

Copy the environmental variable example file:

```
cp env/dev.env.example env/dev.env
```

Then uncomment and update environmental variables to fit your use-case. Not all
variables need to be used. Depending on the value, leaving it commented out
will fallback to a default or disable a feature.

To generate keys, run `mix pyre.gen.token` from the command line and then
update `PYRE_WEBSOCKET_SERVICE_TOKENS_CSV` and `PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN` in `env/dev.env`.

## Quick start

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`
* Configure the server `pyre_lib` and client `pyre_client`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Configuration

Key environment variables are documented in `env/dev.env.example`. Notable:

| Variable | Config key | Description |
|----------|-----------|-------------|
| `PYRE_ALLOWED_PATHS` | `config :pyre_client, :allowed_paths` | Comma-separated directories agents can access |
| `PYRE_WEBSOCKET_SERVICE_TOKENS_CSV` | `config :pyre, :websocket_service_tokens` | Server-side WebSocket auth tokens |
| `PYRE_CLIENT_WEBSOCKET_SERVICE_TOKEN` | `config :pyre_client, :service_token` | Client-side WebSocket auth token |

See [Pyre Client](https://github.com/chrislaskey/pyre_client) for client
configuration details and [Pyre Lib](https://github.com/chrislaskey/pyre_lib)
for server configuration details.

## Learn more about Pyre

* Official repository: [https://github.com/chrislaskey/pyre](https://github.com/chrislaskey/pyre)
