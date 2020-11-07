# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :pluma_api,
  ecto_repos: [PlumaApi.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :pluma_api, PlumaApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "hUdiXce82OtczgFfpUQSVUXs/nRASuEUsZc8kIPhYRaeCQHRbnyzvXddu+F2aebf",
  render_errors: [view: PlumaApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: PlumaApi.PubSub,
  live_view: [signing_salt: "fGdBi+N/"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Defaults for NanoID generator
config :nanoid,
  size: 9,
  alphabet: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

# Params for the mailchimp API
config :pluma_api, :mailchimp, 
  main_list: "main",
  main_list_id: "4cc41938a8",
  premium_list: "premium",
  api_key: "d653f0705d495611865bc7ca6de63515-us2",
  api_server: "us2",
  mailosaur_server: "uoueuw4o",
  mailosaur_api_key: "eGdHsGtsJDRrfp1",
  transactional_api_key: "hFgDYX00lAioKnUSOELCDw"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
