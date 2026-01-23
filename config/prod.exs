import Config

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration
# The vast majority of production config goes in runtime.exs
# since it needs environment variables.
