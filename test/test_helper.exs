# Try to start Wallaby for E2E tests
# If chromedriver isn't available, E2E tests will be excluded
wallaby_started =
  try do
    {:ok, _} = Application.ensure_all_started(:wallaby)
    Application.put_env(:wallaby, :base_url, ProductiveWorkgroupsWeb.Endpoint.url())
    true
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

if wallaby_started do
  ExUnit.start()
else
  IO.puts("Wallaby not started - chromedriver not available. E2E tests excluded.")
  ExUnit.start(exclude: [:e2e])
end

Ecto.Adapters.SQL.Sandbox.mode(ProductiveWorkgroups.Repo, :manual)
