defmodule ProductiveWorkgroups.Repo do
  use Ecto.Repo,
    otp_app: :productive_workgroups,
    adapter: Ecto.Adapters.Postgres
end
