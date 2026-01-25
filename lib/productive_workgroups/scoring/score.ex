defmodule ProductiveWorkgroups.Scoring.Score do
  @moduledoc """
  Schema for participant scores.

  A score represents a single participant's response to a question
  in a workshop session. Scores remain hidden until all participants
  have submitted, then are revealed simultaneously.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.{Participant, Session}

  schema "scores" do
    field :question_index, :integer
    field :value, :integer
    field :submitted_at, :utc_datetime
    field :revealed, :boolean, default: false

    belongs_to :session, Session
    belongs_to :participant, Participant

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(score, attrs) do
    score
    |> cast(attrs, [:question_index, :value, :submitted_at, :revealed])
    |> validate_required([:question_index, :value, :submitted_at])
    |> validate_number(:question_index, greater_than_or_equal_to: 0)
    |> unique_constraint([:participant_id, :question_index])
  end

  @doc """
  Changeset for submitting a new score.
  """
  def submit_changeset(score, session, participant, attrs) do
    score
    |> changeset(attrs)
    |> put_assoc(:session, session)
    |> put_assoc(:participant, participant)
  end

  @doc """
  Changeset for updating an existing score value.
  """
  def update_changeset(score, attrs) do
    score
    |> cast(attrs, [:value, :submitted_at])
    |> validate_required([:value, :submitted_at])
  end

  @doc """
  Adds validation for score value within the question's scale range.
  """
  def validate_value_range(changeset, scale_min, scale_max) do
    validate_change(changeset, :value, fn :value, value ->
      if value >= scale_min and value <= scale_max do
        []
      else
        [value: "must be between #{scale_min} and #{scale_max}"]
      end
    end)
  end
end
