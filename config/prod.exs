import Config

# Do not print debug messages in production
config :logger, level: :info

# Disable swoosh api client as it is only required for production adapters
# that use an API. Since we're using local/test adapters or not sending
# emails yet, disable it.
config :swoosh, :api_client, false

# Runtime production configuration
# The vast majority of production config goes in runtime.exs
# since it needs environment variables.
