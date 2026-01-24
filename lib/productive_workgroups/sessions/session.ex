defmodule ProductiveWorkgroups.Sessions.Session do
  @moduledoc """
  Schema for workshop sessions.

  A session represents a single instance of a workshop being conducted
  by a team. It tracks the current state, participants, and progress
  through the workshop flow.

  ## States

  Sessions progress through the following states:
  - `lobby` - Initial state, waiting for participants to join
  - `intro` - Introduction phase (can be skipped)
  - `scoring` - Main phase, cycling through questions
  - `summary` - Review of all scores
  - `actions` - Action planning phase
  - `completed` - Workshop finished
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Workshops.Template
  alias ProductiveWorkgroups.Sessions.Participant

  @states ~w(lobby intro scoring summary actions completed)

  schema "sessions" do
    field :code, :string
    field :state, :string, default: "lobby"
    field :current_question_index, :integer, default: 0
    field :planned_duration_minutes, :integer
    field :settings, :map, default: %{}
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :last_activity_at, :utc_datetime

    belongs_to :template, Template
    has_many :participants, Participant

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid session states.
  """
  def states, do: @states

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :code,
      :state,
      :current_question_index,
      :planned_duration_minutes,
      :settings,
      :started_at,
      :completed_at,
      :last_activity_at
    ])
    |> validate_required([:code])
    |> validate_inclusion(:state, @states)
    |> validate_number(:current_question_index, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
    |> normalize_code()
  end

  @doc """
  Changeset for creating a new session.
  """
  def create_changeset(session, template, attrs) do
    session
    |> changeset(attrs)
    |> put_assoc(:template, template)
    |> put_change(:last_activity_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  @doc """
  Changeset for state transitions.
  """
  def transition_changeset(session, new_state, additional_changes \\ %{}) do
    changes =
      Map.merge(
        %{state: new_state, last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second)},
        additional_changes
      )

    session
    |> cast(changes, [:state, :started_at, :completed_at, :current_question_index, :last_activity_at])
    |> validate_inclusion(:state, @states)
  end

  defp normalize_code(changeset) do
    case get_change(changeset, :code) do
      nil -> changeset
      code -> put_change(changeset, :code, String.upcase(code))
    end
  end
end
