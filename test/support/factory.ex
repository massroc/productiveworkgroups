defmodule ProductiveWorkgroups.Factory do
  @moduledoc """
  Test factory for building and inserting test data.

  Uses ExMachina for generating test fixtures.

  ## Usage

      # Build a struct without inserting
      build(:session)

      # Build with attributes
      build(:session, code: "ABC123")

      # Insert into database
      insert(:session)

      # Build params map for form testing
      params_for(:session)
  """

  use ExMachina.Ecto, repo: ProductiveWorkgroups.Repo

  alias ProductiveWorkgroups.Facilitation.Timer
  alias ProductiveWorkgroups.Notes.{Action, Note}
  alias ProductiveWorkgroups.Scoring.Score
  alias ProductiveWorkgroups.Sessions.{Participant, Session}
  alias ProductiveWorkgroups.Workshops.{Question, Template}

  @doc """
  Generate a unique session code.
  """
  def unique_session_code do
    sequence(:session_code, fn n ->
      String.upcase(:crypto.strong_rand_bytes(3) |> Base.encode16()) <> "#{n}"
    end)
  end

  @doc """
  Generate a unique participant name.
  """
  def unique_participant_name do
    sequence(:participant_name, &"Participant #{&1}")
  end

  # Template factory
  def template_factory do
    %Template{
      name: sequence(:template_name, &"Workshop #{&1}"),
      slug: sequence(:template_slug, &"workshop-#{&1}"),
      description: "A test workshop for exploring team dynamics",
      version: "1.0.0",
      default_duration_minutes: 210
    }
  end

  # Question factory
  def question_factory do
    %Question{
      index: sequence(:question_index, & &1),
      title: sequence(:question_title, &"Question #{&1}"),
      criterion_number: sequence(:criterion_number, &"#{&1}"),
      criterion_name: "Test Criterion",
      explanation: "This is a test question explanation.",
      scale_type: "balance",
      scale_min: -5,
      scale_max: 5,
      optimal_value: 0,
      discussion_prompts: ["What do you think about this?", "Any surprises?"],
      scoring_guidance: "-5 = Low, 0 = Balanced, +5 = High",
      template: build(:template)
    }
  end

  def maximal_question_factory do
    struct!(
      question_factory(),
      %{
        scale_type: "maximal",
        scale_min: 0,
        scale_max: 10,
        optimal_value: nil,
        scoring_guidance: "0 = Low, 10 = High"
      }
    )
  end

  # Session factory
  def session_factory do
    %Session{
      code: unique_session_code(),
      state: "lobby",
      current_question_index: 0,
      settings: %{},
      last_activity_at: DateTime.utc_now() |> DateTime.truncate(:second),
      template: build(:template)
    }
  end

  def started_session_factory do
    struct!(
      session_factory(),
      %{
        state: "intro",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    )
  end

  def scoring_session_factory do
    struct!(
      session_factory(),
      %{
        state: "scoring",
        current_question_index: 0,
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    )
  end

  # Participant factory
  def participant_factory do
    %Participant{
      name: unique_participant_name(),
      browser_token: Ecto.UUID.generate(),
      status: "active",
      is_ready: false,
      joined_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_seen_at: DateTime.utc_now() |> DateTime.truncate(:second),
      session: build(:session)
    }
  end

  # Score factory
  def score_factory do
    %Score{
      question_index: 0,
      value: 0,
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second),
      revealed: false,
      session: build(:session),
      participant: build(:participant)
    }
  end

  # Note factory
  def note_factory do
    %Note{
      question_index: 0,
      content: sequence(:note_content, &"Discussion note #{&1}"),
      author_name: "Test Author",
      session: build(:session)
    }
  end

  def general_note_factory do
    struct!(
      note_factory(),
      %{question_index: nil}
    )
  end

  # Action factory
  def action_factory do
    %Action{
      question_index: 0,
      description: sequence(:action_description, &"Action item #{&1}"),
      owner_name: nil,
      completed: false,
      session: build(:session)
    }
  end

  def general_action_factory do
    struct!(
      action_factory(),
      %{question_index: nil}
    )
  end

  # Timer factory
  def timer_factory do
    %Timer{
      phase: sequence(:timer_phase, &"phase_#{&1}"),
      duration_seconds: 300,
      remaining_seconds: 300,
      status: "stopped",
      session: build(:session)
    }
  end

  def running_timer_factory do
    struct!(
      timer_factory(),
      %{
        status: "running",
        started_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    )
  end
end
