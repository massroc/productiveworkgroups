defmodule ProductiveWorkgroups.Facilitation.Timer do
  @moduledoc """
  Schema for session timers.

  Timers track time allocation for different phases of the workshop.
  They support start, pause, resume, and stop operations.

  ## Statuses

  - `stopped` - Timer not started or has been reset
  - `running` - Timer actively counting down
  - `paused` - Timer temporarily stopped, can be resumed
  - `exceeded` - Timer has run past its duration
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ProductiveWorkgroups.Sessions.Session

  @statuses ~w(stopped running paused exceeded)

  schema "timers" do
    field :phase, :string
    field :duration_seconds, :integer
    field :remaining_seconds, :integer
    field :status, :string, default: "stopped"
    field :started_at, :utc_datetime
    field :paused_at, :utc_datetime

    belongs_to :session, Session

    timestamps(type: :utc_datetime)
  end

  @doc """
  Returns the list of valid timer statuses.
  """
  def statuses, do: @statuses

  @doc false
  def changeset(timer, attrs) do
    timer
    |> cast(attrs, [:phase, :duration_seconds, :remaining_seconds, :status, :started_at, :paused_at])
    |> validate_required([:phase, :duration_seconds, :remaining_seconds])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:duration_seconds, greater_than: 0)
    |> validate_number(:remaining_seconds, greater_than_or_equal_to: 0)
    |> unique_constraint(:phase, name: :timers_session_id_phase_index)
  end

  @doc """
  Changeset for creating a timer.
  """
  def create_changeset(timer, session, attrs) do
    timer
    |> changeset(attrs)
    |> put_assoc(:session, session)
  end

  @doc """
  Changeset for starting a timer.
  """
  def start_changeset(timer) do
    timer
    |> cast(
      %{
        status: "running",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second),
        paused_at: nil
      },
      [:status, :started_at, :paused_at]
    )
  end

  @doc """
  Changeset for pausing a timer.
  """
  def pause_changeset(timer, remaining_seconds) do
    timer
    |> cast(
      %{
        status: "paused",
        remaining_seconds: remaining_seconds,
        paused_at: DateTime.utc_now() |> DateTime.truncate(:second)
      },
      [:status, :remaining_seconds, :paused_at]
    )
  end

  @doc """
  Changeset for stopping a timer.
  """
  def stop_changeset(timer) do
    timer
    |> cast(%{status: "stopped"}, [:status])
  end

  @doc """
  Changeset for resetting a timer.
  """
  def reset_changeset(timer) do
    timer
    |> cast(
      %{
        status: "stopped",
        remaining_seconds: timer.duration_seconds,
        started_at: nil,
        paused_at: nil
      },
      [:status, :remaining_seconds, :started_at, :paused_at]
    )
  end

  @doc """
  Changeset for marking a timer as exceeded.
  """
  def exceeded_changeset(timer) do
    timer
    |> cast(%{status: "exceeded", remaining_seconds: 0}, [:status, :remaining_seconds])
  end
end
