defmodule ProductiveWorkgroups.Export do
  @moduledoc """
  Handles exporting workshop data to various formats (CSV, JSON).
  """

  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Scoring
  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Sessions.Session

  @doc """
  Exports workshop data to the specified format.

  ## Options
  - `:content` - What to export: :results, :actions, or :all (default: :all)
  - `:format` - Export format: :csv or :json (default: :csv)

  Returns `{:ok, {filename, content_type, data}}` or `{:error, reason}`
  """
  def export(%Session{} = session, opts \\ []) do
    content = Keyword.get(opts, :content, :all)
    format = Keyword.get(opts, :format, :csv)

    session = Sessions.get_session_with_all(session.id)
    template = session.template
    participants = Sessions.list_participants(session)
    scores_summary = Scoring.get_all_scores_summary(session, template)
    individual_scores = Scoring.get_all_individual_scores(session, participants, template)
    notes = Notes.list_all_notes(session)
    actions = Notes.list_all_actions(session)

    data = %{
      session: session,
      template: template,
      participants: participants,
      scores_summary: scores_summary,
      individual_scores: individual_scores,
      notes: notes,
      actions: actions
    }

    case format do
      :csv -> export_csv(data, content, session.code)
      :json -> export_json(data, content, session.code)
      _ -> {:error, :invalid_format}
    end
  end

  # CSV Export

  defp export_csv(data, content, code) do
    csv_content =
      case content do
        :results -> build_results_csv(data)
        :actions -> build_actions_csv(data)
        :all -> build_results_csv(data) <> "\n\n" <> build_actions_csv(data)
      end

    filename = "workshop_#{code}_#{content}.csv"
    {:ok, {filename, "text/csv", csv_content}}
  end

  defp build_results_csv(data) do
    session_section = build_session_info_csv(data.session)
    participants_section = build_participants_csv(data.participants)

    scores_section =
      build_scores_csv(data.scores_summary, data.individual_scores, data.participants)

    notes_section = build_notes_csv(data.notes, data.scores_summary)

    Enum.join([session_section, participants_section, scores_section, notes_section], "\n\n")
  end

  defp build_session_info_csv(session) do
    started = format_datetime(session.started_at)
    completed = format_datetime(session.completed_at)

    """
    SESSION INFORMATION
    Session Code,#{session.code}
    Started,#{started}
    Completed,#{completed}
    """
    |> String.trim()
  end

  defp build_participants_csv(participants) do
    header = "PARTICIPANTS\nName,Role,Status"
    rows = Enum.map_join(participants, "\n", &format_participant_row/1)
    header <> "\n" <> rows
  end

  defp format_participant_row(p) do
    role = participant_role(p)
    "#{csv_escape(p.name)},#{role},#{p.status}"
  end

  defp participant_role(%{is_facilitator: true}), do: "Facilitator"
  defp participant_role(%{is_observer: true}), do: "Observer"
  defp participant_role(_), do: "Participant"

  defp build_scores_csv(scores_summary, individual_scores, participants) do
    participant_names = Enum.map(participants, & &1.name)

    header =
      "SCORES\nQuestion,Team Score," <> Enum.map_join(participant_names, ",", &csv_escape/1)

    rows =
      Enum.map_join(scores_summary, "\n", fn score ->
        format_score_row(score, individual_scores, participants)
      end)

    header <> "\n" <> rows
  end

  defp format_score_row(score, individual_scores, participants) do
    question_scores = Map.get(individual_scores, score.question_index, [])

    score_values =
      Enum.map_join(
        participants,
        ",",
        &get_participant_score(&1, question_scores, score.scale_type)
      )

    team_value =
      if score.combined_team_value, do: "#{round(score.combined_team_value)}/10", else: ""

    "#{csv_escape(score.title)},#{team_value},#{score_values}"
  end

  defp get_participant_score(participant, question_scores, scale_type) do
    case Enum.find(question_scores, &(&1.participant_id == participant.id)) do
      nil -> ""
      s -> format_score_value(s.value, scale_type)
    end
  end

  defp build_notes_csv(notes, scores_summary) do
    if Enum.empty?(notes) do
      "NOTES\nNo notes recorded"
    else
      header = "NOTES\nQuestion,Note,Author"
      rows = Enum.map_join(notes, "\n", &format_note_row(&1, scores_summary))
      header <> "\n" <> rows
    end
  end

  defp format_note_row(note, scores_summary) do
    question_title = get_question_title(note.question_index, scores_summary)
    "#{csv_escape(question_title)},#{csv_escape(note.content)},#{csv_escape(note.author_name)}"
  end

  defp get_question_title(question_index, scores_summary) do
    case Enum.find(scores_summary, &(&1.question_index == question_index)) do
      nil -> "Q#{(question_index || 0) + 1}"
      q -> q.title
    end
  end

  defp build_actions_csv(data) do
    if Enum.empty?(data.actions) do
      "ACTION ITEMS\nNo action items recorded"
    else
      header = "ACTION ITEMS\nAction,Owner,Created"
      rows = Enum.map_join(data.actions, "\n", &format_action_row/1)
      header <> "\n" <> rows
    end
  end

  defp format_action_row(action) do
    owner = action.owner_name || ""
    created = format_datetime(action.inserted_at)
    "#{csv_escape(action.description)},#{csv_escape(owner)},#{created}"
  end

  # JSON Export

  defp export_json(data, content, code) do
    json_data =
      case content do
        :results -> build_results_json(data)
        :actions -> build_actions_json(data)
        :all -> Map.merge(build_results_json(data), build_actions_json(data))
      end

    json_content = Jason.encode!(json_data, pretty: true)
    filename = "workshop_#{code}_#{content}.json"
    {:ok, {filename, "application/json", json_content}}
  end

  defp build_results_json(data) do
    %{
      session: %{
        code: data.session.code,
        started_at: format_datetime(data.session.started_at),
        completed_at: format_datetime(data.session.completed_at)
      },
      participants:
        Enum.map(data.participants, fn p ->
          %{
            name: p.name,
            role:
              if(p.is_facilitator,
                do: "facilitator",
                else: if(p.is_observer, do: "observer", else: "participant")
              ),
            status: p.status
          }
        end),
      questions:
        Enum.map(data.scores_summary, fn score ->
          question_scores = Map.get(data.individual_scores, score.question_index, [])

          %{
            index: score.question_index + 1,
            title: score.title,
            scale_type: score.scale_type,
            combined_team_value:
              if(score.combined_team_value, do: round(score.combined_team_value), else: nil),
            average: score.average,
            min: score.min,
            max: score.max,
            individual_scores:
              Enum.map(question_scores, fn s ->
                %{
                  participant: s.participant_name,
                  value: s.value,
                  color: s.color
                }
              end)
          }
        end),
      notes:
        Enum.map(data.notes, fn note ->
          question_title =
            case Enum.find(data.scores_summary, &(&1.question_index == note.question_index)) do
              nil -> "Q#{(note.question_index || 0) + 1}"
              q -> q.title
            end

          %{
            question: question_title,
            content: note.content,
            author: note.author_name
          }
        end)
    }
  end

  defp build_actions_json(data) do
    %{
      actions:
        Enum.map(data.actions, fn action ->
          %{
            description: action.description,
            owner: action.owner_name,
            created_at: format_datetime(action.inserted_at)
          }
        end)
    }
  end

  # Helpers

  defp csv_escape(nil), do: ""

  defp csv_escape(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp csv_escape(value), do: to_string(value)

  defp format_score_value(value, "balance") when value > 0, do: "+#{value}"
  defp format_score_value(value, _scale_type), do: to_string(value)

  defp format_datetime(nil), do: ""

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  end
end
