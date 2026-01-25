defmodule ProductiveWorkgroups.Scoring do
  @moduledoc """
  The Scoring context.

  This context manages score submission, validation, aggregation,
  and traffic light color determination for workshop questions.
  """

  import Ecto.Query, warn: false

  alias ProductiveWorkgroups.Repo
  alias ProductiveWorkgroups.Scoring.Score
  alias ProductiveWorkgroups.Sessions.{Participant, Session}
  alias ProductiveWorkgroups.Workshops
  alias ProductiveWorkgroups.Workshops.Template

  ## Score Submission

  @doc """
  Submits or updates a participant's score for a question.

  Validates the score value against the question's scale range.
  """
  def submit_score(%Session{} = session, %Participant{} = participant, question_index, value) do
    session = Repo.preload(session, :template)
    question = Workshops.get_question(session.template, question_index)

    attrs = %{
      question_index: question_index,
      value: value,
      submitted_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    case get_score(session, participant, question_index) do
      nil ->
        %Score{}
        |> Score.submit_changeset(session, participant, attrs)
        |> Score.validate_value_range(question.scale_min, question.scale_max)
        |> Repo.insert()

      existing ->
        existing
        |> Score.update_changeset(attrs)
        |> Score.validate_value_range(question.scale_min, question.scale_max)
        |> Repo.update()
    end
  end

  @doc """
  Gets a participant's score for a specific question.
  """
  def get_score(%Session{} = session, %Participant{} = participant, question_index) do
    Repo.get_by(Score,
      session_id: session.id,
      participant_id: participant.id,
      question_index: question_index
    )
  end

  @doc """
  Lists all scores for a question in a session.
  """
  def list_scores_for_question(%Session{} = session, question_index) do
    Score
    |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
    |> Repo.all()
  end

  @doc """
  Counts the number of scores submitted for a question.
  """
  def count_scores(%Session{} = session, question_index) do
    Score
    |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
    |> Repo.aggregate(:count)
  end

  @doc """
  Marks all scores for a question as revealed.
  """
  def reveal_scores(%Session{} = session, question_index) do
    Score
    |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
    |> Repo.update_all(set: [revealed: true])

    :ok
  end

  @doc """
  Checks if all active participants have submitted scores for a question.
  """
  def all_scored?(%Session{} = session, question_index) do
    active_count =
      Participant
      |> where([p], p.session_id == ^session.id and p.status == "active")
      |> Repo.aggregate(:count)

    score_count = count_scores(session, question_index)

    active_count > 0 and active_count == score_count
  end

  ## Score Aggregation

  @doc """
  Calculates the average score for a question.
  """
  def calculate_average(%Session{} = session, question_index) do
    result =
      Score
      |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
      |> select([s], avg(s.value))
      |> Repo.one()

    case result do
      nil -> nil
      avg -> Float.round(Decimal.to_float(avg), 1)
    end
  end

  @doc """
  Calculates the spread (min, max) of scores for a question.
  """
  def calculate_spread(%Session{} = session, question_index) do
    result =
      Score
      |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
      |> select([s], {min(s.value), max(s.value)})
      |> Repo.one()

    case result do
      {nil, nil} -> nil
      spread -> spread
    end
  end

  @doc """
  Gets a comprehensive summary of scores for a question.

  Returns a map with:
  - `:count` - Number of scores
  - `:average` - Mean score
  - `:min` - Minimum score
  - `:max` - Maximum score
  - `:spread` - Difference between max and min
  """
  def get_score_summary(%Session{} = session, question_index) do
    scores = list_scores_for_question(session, question_index)

    case scores do
      [] ->
        %{count: 0, average: nil, min: nil, max: nil, spread: nil}

      scores ->
        values = Enum.map(scores, & &1.value)

        %{
          count: length(values),
          average: Float.round(Enum.sum(values) / length(values), 1),
          min: Enum.min(values),
          max: Enum.max(values),
          spread: Enum.max(values) - Enum.min(values)
        }
    end
  end

  @doc """
  Gets score summaries for all questions in a session.
  """
  def get_all_scores_summary(%Session{} = session, %Template{} = template) do
    questions = Workshops.list_questions(template)

    Enum.map(questions, fn question ->
      summary = get_score_summary(session, question.index)

      Map.merge(summary, %{
        question_index: question.index,
        title: question.title,
        scale_type: question.scale_type,
        optimal_value: question.optimal_value,
        color:
          if(summary.average,
            do: traffic_light_color(question.scale_type, summary.average, question.optimal_value),
            else: nil
          )
      })
    end)
  end

  ## Traffic Light Colors

  @doc """
  Determines the traffic light color for a score.

  ## Balance Scale (optimal at 0)
  - Green: within ±1 of optimal (0)
  - Amber: within ±2-3 of optimal
  - Red: ±4-5 from optimal

  ## Maximal Scale (more is better, 0-10)
  - Green: 7-10
  - Amber: 4-6
  - Red: 0-3
  """
  def traffic_light_color("balance", value, optimal_value) do
    deviation = abs(value - (optimal_value || 0))

    cond do
      deviation <= 1 -> :green
      deviation <= 3 -> :amber
      true -> :red
    end
  end

  def traffic_light_color("maximal", value, _optimal_value) do
    cond do
      value >= 7 -> :green
      value >= 4 -> :amber
      true -> :red
    end
  end
end
