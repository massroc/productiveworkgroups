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

  # alias ProductiveWorkgroups.Workshops.Template
  # alias ProductiveWorkgroups.Sessions.Session
  # alias ProductiveWorkgroups.Sessions.Participant
  # alias ProductiveWorkgroups.Scoring.Score

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

  # Example factory definitions (uncomment when schemas are created):

  # def template_factory do
  #   %Template{
  #     name: "Six Criteria Workshop",
  #     slug: "six-criteria",
  #     description: "Explore the six criteria of productive work",
  #     version: "1.0.0",
  #     default_duration_minutes: 210
  #   }
  # end

  # def session_factory do
  #   %Session{
  #     code: unique_session_code(),
  #     state: :lobby,
  #     current_question_index: 0,
  #     settings: %{},
  #     template: build(:template)
  #   }
  # end

  # def participant_factory do
  #   %Participant{
  #     name: unique_participant_name(),
  #     browser_token: Ecto.UUID.generate(),
  #     status: :active,
  #     session: build(:session)
  #   }
  # end

  # def score_factory do
  #   %Score{
  #     value: Enum.random(0..10),
  #     participant: build(:participant),
  #     question_index: 0
  #   }
  # end
end
