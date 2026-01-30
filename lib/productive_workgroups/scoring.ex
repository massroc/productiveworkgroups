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
  Marks all scores for a question as unrevealed.

  Used when going back to a previous question to allow participants to change their scores.
  """
  def unreveal_scores(%Session{} = session, question_index) do
    Score
    |> where([s], s.session_id == ^session.id and s.question_index == ^question_index)
    |> Repo.update_all(set: [revealed: false])

    :ok
  end

  @doc """
  Checks if all active non-observer participants have submitted scores for a question.
  """
  def all_scored?(%Session{} = session, question_index) do
    active_count =
      Participant
      |> where(
        [p],
        p.session_id == ^session.id and p.status == "active" and p.is_observer == false
      )
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

  Optimized to load all scores in a single query instead of N+1 queries.
  """
  def get_all_scores_summary(%Session{} = session, %Template{} = template) do
    questions = Workshops.list_questions(template)

    # Single query to get all scores for this session, grouped by question_index
    all_scores =
      Score
      |> where([s], s.session_id == ^session.id)
      |> Repo.all()
      |> Enum.group_by(& &1.question_index)

    Enum.map(questions, fn question ->
      scores = Map.get(all_scores, question.index, [])
      summary = calculate_summary_from_scores(scores)

      Map.merge(summary, %{
        question_index: question.index,
        title: question.title,
        scale_type: question.scale_type,
        optimal_value: question.optimal_value,
        color:
          if(summary.average,
            do: traffic_light_color(question.scale_type, summary.average, question.optimal_value),
            else: nil
          ),
        combined_team_value:
          calculate_combined_team_value(scores, question.scale_type, question.optimal_value)
      })
    end)
  end

  # Calculate summary stats from a list of scores (no database query)
  defp calculate_summary_from_scores([]) do
    %{count: 0, average: nil, min: nil, max: nil, spread: nil}
  end

  defp calculate_summary_from_scores(scores) do
    values = Enum.map(scores, & &1.value)

    %{
      count: length(values),
      average: Float.round(Enum.sum(values) / length(values), 1),
      min: Enum.min(values),
      max: Enum.max(values),
      spread: Enum.max(values) - Enum.min(values)
    }
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

  @doc """
  Converts a traffic light color to grade points.

  - Green: 2 points (good)
  - Amber: 1 point (medium)
  - Red: 0 points (low)
  """
  def color_to_grade(:green), do: 2
  def color_to_grade(:amber), do: 1
  def color_to_grade(:red), do: 0
  def color_to_grade(_), do: 0

  @doc """
  Calculates the Combined Team Value for a question.

  This score represents how well the team is performing on this criterion,
  accounting for variance by grading individual scores:
  - Each person's score is graded: green = 2, amber = 1, red = 0
  - Grades are summed and divided by number of participants
  - Result is scaled to 0-10

  A score of 10 means everyone had a "good" score.
  A score of 0 means everyone had a "low" score.
  """
  def calculate_combined_team_value([], _scale_type, _optimal_value), do: nil

  def calculate_combined_team_value(scores, scale_type, optimal_value) do
    grades =
      Enum.map(scores, fn score ->
        color = traffic_light_color(scale_type, score.value, optimal_value)
        color_to_grade(color)
      end)

    total_grades = Enum.sum(grades)
    num_participants = length(grades)

    # Scale from 0-2 average to 0-10
    # Max possible: 2 (everyone green) * 5 = 10
    # Min possible: 0 (everyone red) * 5 = 0
    Float.round(total_grades / num_participants * 5, 1)
  end

  @doc """
  Gets all individual scores for a session, organized by question index.

  Returns a map where keys are question indices and values are lists of scores
  with participant information, ordered by participant's `joined_at` timestamp.

  Each score entry includes:
  - `:value` - The score value
  - `:participant_id` - The participant's ID
  - `:participant_name` - The participant's name
  - `:color` - The traffic light color for the score

  ## Parameters
  - `session` - The session to get scores for
  - `participants` - List of participants (already ordered by joined_at)
  - `template` - The workshop template with questions

  ## Example

      iex> get_all_individual_scores(session, participants, template)
      %{
        0 => [
          %{value: 3, participant_id: "...", participant_name: "Alice", color: :amber},
          %{value: -1, participant_id: "...", participant_name: "Bob", color: :green}
        ],
        1 => [...]
      }
  """
  def get_all_individual_scores(%Session{} = session, participants, %Template{} = template) do
    questions = Workshops.list_questions(template)

    # Build order map: participant_id => order_index (for sorting by arrival order)
    participant_order =
      participants
      |> Enum.with_index()
      |> Map.new(fn {p, idx} -> {p.id, idx} end)

    # Build participant name map for O(1) lookups
    participant_names = Map.new(participants, &{&1.id, &1.name})

    # Single query to get all scores for this session
    all_scores =
      Score
      |> where([s], s.session_id == ^session.id)
      |> Repo.all()
      |> Enum.group_by(& &1.question_index)

    # Build question map for color calculations (used below in the mapping)

    # Process each question
    Map.new(questions, fn question ->
      scores = Map.get(all_scores, question.index, [])

      ordered_scores =
        scores
        |> Enum.map(fn score ->
          %{
            value: score.value,
            participant_id: score.participant_id,
            participant_name: Map.get(participant_names, score.participant_id, "Unknown"),
            color: traffic_light_color(question.scale_type, score.value, question.optimal_value)
          }
        end)
        |> Enum.sort_by(fn s -> Map.get(participant_order, s.participant_id, 999) end)

      {question.index, ordered_scores}
    end)
  end
end
