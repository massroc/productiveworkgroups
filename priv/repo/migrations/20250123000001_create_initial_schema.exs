defmodule ProductiveWorkgroups.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def change do
    # Templates table - workshop definitions
    create table(:templates) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :version, :string, null: false, default: "1.0.0"
      add :default_duration_minutes, :integer, null: false, default: 210

      timestamps(type: :utc_datetime)
    end

    create unique_index(:templates, [:slug])

    # Questions table - individual questions in a template
    create table(:questions) do
      add :template_id, references(:templates, on_delete: :delete_all), null: false
      add :index, :integer, null: false
      add :title, :string, null: false
      add :criterion_name, :string, null: false
      add :explanation, :text, null: false
      add :scale_type, :string, null: false  # "balance" or "maximal"
      add :scale_min, :integer, null: false
      add :scale_max, :integer, null: false
      add :optimal_value, :integer  # null for maximal scales (more is better)
      add :discussion_prompts, {:array, :string}, default: []
      add :scoring_guidance, :text

      timestamps(type: :utc_datetime)
    end

    create index(:questions, [:template_id])
    create unique_index(:questions, [:template_id, :index])

    # Sessions table - workshop instances
    create table(:sessions) do
      add :code, :string, null: false, size: 8
      add :template_id, references(:templates, on_delete: :restrict), null: false
      add :state, :string, null: false, default: "lobby"
      add :current_question_index, :integer, null: false, default: 0
      add :planned_duration_minutes, :integer
      add :settings, :map, default: %{}
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :last_activity_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sessions, [:code])
    create index(:sessions, [:state])
    create index(:sessions, [:last_activity_at])

    # Participants table - people in a session
    create table(:participants) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :browser_token, :uuid, null: false
      add :status, :string, null: false, default: "active"  # active, inactive, dropped
      add :is_ready, :boolean, null: false, default: false
      add :joined_at, :utc_datetime, null: false
      add :last_seen_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:participants, [:session_id])
    create unique_index(:participants, [:session_id, :browser_token])
    create index(:participants, [:session_id, :status])

    # Scores table - individual participant scores
    create table(:scores) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :participant_id, references(:participants, on_delete: :delete_all), null: false
      add :question_index, :integer, null: false
      add :value, :integer, null: false
      add :submitted_at, :utc_datetime, null: false
      add :revealed, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:scores, [:session_id, :question_index])
    create unique_index(:scores, [:participant_id, :question_index])

    # Notes table - discussion notes
    create table(:notes) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :question_index, :integer  # null for general session notes
      add :content, :text, null: false
      add :author_name, :string  # name of participant who added it

      timestamps(type: :utc_datetime)
    end

    create index(:notes, [:session_id])
    create index(:notes, [:session_id, :question_index])

    # Actions table - action items
    create table(:actions) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :question_index, :integer  # null for general actions
      add :description, :text, null: false
      add :owner_name, :string  # optional owner
      add :completed, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:actions, [:session_id])

    # Timers table - section timers
    create table(:timers) do
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :phase, :string, null: false  # intro, question_1, etc.
      add :duration_seconds, :integer, null: false
      add :remaining_seconds, :integer, null: false
      add :status, :string, null: false, default: "stopped"  # stopped, running, paused, exceeded
      add :started_at, :utc_datetime
      add :paused_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:timers, [:session_id])
    create unique_index(:timers, [:session_id, :phase])

    # Feedback table - user feedback
    create table(:feedback) do
      add :session_id, references(:sessions, on_delete: :nilify_all)
      add :category, :string, null: false  # bug, feature, general
      add :content, :text, null: false
      add :page_context, :string  # which page/phase they were on
      add :user_agent, :string

      timestamps(type: :utc_datetime)
    end

    create index(:feedback, [:category])
    create index(:feedback, [:inserted_at])
  end
end
