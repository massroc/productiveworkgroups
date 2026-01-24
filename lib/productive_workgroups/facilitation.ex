defmodule ProductiveWorkgroups.Facilitation do
  @moduledoc """
  The Facilitation context.

  This context manages workshop facilitation features including:
  - Timer management for different phases
  - Phase transitions and progress tracking
  - Contextual guidance and prompts
  """

  import Ecto.Query, warn: false
  alias ProductiveWorkgroups.Repo
  alias ProductiveWorkgroups.Facilitation.Timer
  alias ProductiveWorkgroups.Sessions.Session

  ## Suggested Durations (in seconds)

  @default_durations %{
    "intro" => 600,      # 10 minutes
    "question" => 900,   # 15 minutes per question
    "summary" => 600,    # 10 minutes
    "actions" => 1200    # 20 minutes
  }

  ## Timer Management

  @doc """
  Creates a timer for a phase.
  """
  def create_timer(%Session{} = session, phase, duration_seconds) do
    %Timer{}
    |> Timer.create_changeset(session, %{
      phase: phase,
      duration_seconds: duration_seconds,
      remaining_seconds: duration_seconds
    })
    |> Repo.insert()
  end

  @doc """
  Gets a timer by phase, or creates one if it doesn't exist.
  """
  def get_or_create_timer(%Session{} = session, phase, duration_seconds) do
    case get_timer(session, phase) do
      nil -> create_timer(session, phase, duration_seconds)
      timer -> {:ok, timer}
    end
  end

  @doc """
  Gets a timer by its phase.
  """
  def get_timer(%Session{} = session, phase) do
    Repo.get_by(Timer, session_id: session.id, phase: phase)
  end

  @doc """
  Lists all timers for a session.
  """
  def list_timers(%Session{} = session) do
    Timer
    |> where([t], t.session_id == ^session.id)
    |> order_by([t], t.phase)
    |> Repo.all()
  end

  @doc """
  Starts a timer.

  If the timer is stopped, starts fresh.
  If the timer is paused, resumes from remaining time.
  """
  def start_timer(%Timer{status: status} = timer) when status in ["stopped", "paused"] do
    timer
    |> Timer.start_changeset()
    |> Repo.update()
  end

  @doc """
  Pauses a running timer.

  Calculates and stores the remaining time.
  """
  def pause_timer(%Timer{status: "running"} = timer) do
    remaining = calculate_remaining(timer)

    timer
    |> Timer.pause_changeset(remaining)
    |> Repo.update()
  end

  @doc """
  Stops a timer.
  """
  def stop_timer(%Timer{} = timer) do
    timer
    |> Timer.stop_changeset()
    |> Repo.update()
  end

  @doc """
  Resets a timer to its initial duration.
  """
  def reset_timer(%Timer{} = timer) do
    timer
    |> Timer.reset_changeset()
    |> Repo.update()
  end

  @doc """
  Marks a timer as exceeded.
  """
  def mark_exceeded(%Timer{} = timer) do
    timer
    |> Timer.exceeded_changeset()
    |> Repo.update()
  end

  @doc """
  Calculates the current remaining seconds for a timer.

  For running timers, calculates based on started_at and current time.
  For other statuses, returns the stored remaining_seconds value.
  """
  def calculate_remaining(%Timer{status: "running"} = timer) do
    elapsed = DateTime.diff(DateTime.utc_now(), timer.started_at, :second)
    max(0, timer.remaining_seconds - elapsed)
  end

  def calculate_remaining(%Timer{} = timer) do
    timer.remaining_seconds
  end

  ## Phase Utilities

  @doc """
  Returns a human-readable name for a phase.
  """
  def phase_name("intro"), do: "Introduction"
  def phase_name("summary"), do: "Summary"
  def phase_name("actions"), do: "Action Planning"

  def phase_name("question_" <> index) do
    "Question #{String.to_integer(index) + 1}"
  end

  def phase_name(phase), do: phase

  @doc """
  Returns the suggested duration for a phase in seconds.
  """
  def suggested_duration("intro"), do: @default_durations["intro"]
  def suggested_duration("summary"), do: @default_durations["summary"]
  def suggested_duration("actions"), do: @default_durations["actions"]

  def suggested_duration("question_" <> _), do: @default_durations["question"]

  def suggested_duration(_), do: 300  # 5 minute default

  @doc """
  Returns the total suggested duration for a complete workshop.
  """
  def total_suggested_duration(num_questions) do
    @default_durations["intro"] +
      (num_questions * @default_durations["question"]) +
      @default_durations["summary"] +
      @default_durations["actions"]
  end
end
