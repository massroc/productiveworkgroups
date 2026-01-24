import Config

# Configure your database for testing
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
config :productive_workgroups, ProductiveWorkgroups.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOST", "localhost"),
  database: "productive_workgroups_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Enable server for Wallaby E2E tests
config :productive_workgroups, ProductiveWorkgroupsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "test_secret_key_base_that_is_at_least_64_characters_long_for_testing_only",
  server: true

# In test we don't send emails
config :productive_workgroups, ProductiveWorkgroups.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Wallaby configuration for E2E tests
config :wallaby,
  driver: Wallaby.Chrome,
  screenshot_on_failure: true,
  js_errors: true,
  chromedriver: [
    path: System.get_env("CHROMEDRIVER_PATH", "/usr/bin/chromedriver"),
    headless: true
  ],
  chrome: [
    headless: true
  ]
