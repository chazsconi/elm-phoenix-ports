# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
import Config

# Configures the endpoint
config :elm_phoenix, ElmPhoenix.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "z8lUp9PvAn11JXBqC27JlAde8qFhWM1wUKoVWft2aHAig6BIIQb/wT7IOpEGjcMu",
  render_errors: [view: ElmPhoenix.Web.ErrorView, accepts: ~w(html json)],
  pubsub_server: ElmPhoenix.PubSub

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
