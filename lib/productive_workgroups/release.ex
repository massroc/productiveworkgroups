defmodule ProductiveWorkgroups.Release do
  @moduledoc """
  Release tasks for database migrations and seeding.

  Used by the release command in fly.toml to run migrations on deployment.
  """

  @app :productive_workgroups

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          # Run the seeds file
          seed_script = Application.app_dir(@app, "priv/repo/seeds.exs")

          if File.exists?(seed_script) do
            # sobelow_skip ["RCE.CodeModule"]
            Code.eval_file(seed_script)
          end
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
