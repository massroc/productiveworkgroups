defmodule ProductiveWorkgroups.Repo.Migrations.AddIsObserverToParticipants do
  use Ecto.Migration

  def change do
    alter table(:participants) do
      add :is_observer, :boolean, default: false, null: false
    end
  end
end
