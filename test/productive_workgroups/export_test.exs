defmodule ProductiveWorkgroups.ExportTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Export
  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Scoring
  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Workshops

  describe "export/2" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Export Test Workshop",
          slug: "export-test",
          version: "1.0.0",
          default_duration_minutes: 120
        })

      # Create two questions
      {:ok, _q1} =
        Workshops.create_question(template, %{
          index: 0,
          title: "Elbow Room",
          criterion_number: "1",
          criterion_name: "Autonomy",
          explanation: "Test explanation",
          scale_type: "balance",
          scale_min: -5,
          scale_max: 5,
          optimal_value: 0
        })

      {:ok, _q2} =
        Workshops.create_question(template, %{
          index: 1,
          title: "Mutual Support",
          criterion_number: "4",
          criterion_name: "Support",
          explanation: "Test explanation",
          scale_type: "maximal",
          scale_min: 0,
          scale_max: 10,
          optimal_value: nil
        })

      {:ok, session} = Sessions.create_session(template)
      {:ok, participant1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, participant2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      # Submit scores
      Scoring.submit_score(session, participant1, 0, 1)
      Scoring.submit_score(session, participant2, 0, -1)
      Scoring.submit_score(session, participant1, 1, 8)
      Scoring.submit_score(session, participant2, 1, 6)

      # Add a note
      {:ok, _note} =
        Notes.create_note(session, 0, %{
          content: "This is a test note",
          author_name: "Alice"
        })

      # Add an action
      {:ok, _action} =
        Notes.create_action(session, %{
          description: "Follow up on feedback",
          owner_name: "Alice"
        })

      %{session: session, template: template}
    end

    test "exports results as CSV", %{session: session} do
      {:ok, {filename, content_type, data}} =
        Export.export(session, format: :csv, content: :results)

      assert filename == "workshop_#{session.code}_results.csv"
      assert content_type == "text/csv"
      assert data =~ "SESSION INFORMATION"
      assert data =~ session.code
      assert data =~ "PARTICIPANTS"
      assert data =~ "Alice"
      assert data =~ "Bob"
      assert data =~ "SCORES"
      assert data =~ "Elbow Room"
      assert data =~ "Mutual Support"
      assert data =~ "NOTES"
      assert data =~ "This is a test note"
    end

    test "exports actions as CSV", %{session: session} do
      {:ok, {filename, content_type, data}} =
        Export.export(session, format: :csv, content: :actions)

      assert filename == "workshop_#{session.code}_actions.csv"
      assert content_type == "text/csv"
      assert data =~ "ACTION ITEMS"
      assert data =~ "Follow up on feedback"
      assert data =~ "Alice"
    end

    test "exports all as CSV", %{session: session} do
      {:ok, {filename, content_type, data}} = Export.export(session, format: :csv, content: :all)

      assert filename == "workshop_#{session.code}_all.csv"
      assert content_type == "text/csv"
      assert data =~ "SESSION INFORMATION"
      assert data =~ "SCORES"
      assert data =~ "ACTION ITEMS"
    end

    test "exports results as JSON", %{session: session} do
      {:ok, {filename, content_type, data}} =
        Export.export(session, format: :json, content: :results)

      assert filename == "workshop_#{session.code}_results.json"
      assert content_type == "application/json"

      decoded = Jason.decode!(data)
      assert decoded["session"]["code"] == session.code
      assert length(decoded["participants"]) == 2
      assert length(decoded["questions"]) == 2
      assert length(decoded["notes"]) == 1
    end

    test "exports actions as JSON", %{session: session} do
      {:ok, {filename, content_type, data}} =
        Export.export(session, format: :json, content: :actions)

      assert filename == "workshop_#{session.code}_actions.json"
      assert content_type == "application/json"

      decoded = Jason.decode!(data)
      assert length(decoded["actions"]) == 1
      assert hd(decoded["actions"])["description"] == "Follow up on feedback"
    end

    test "exports all as JSON", %{session: session} do
      {:ok, {filename, content_type, data}} = Export.export(session, format: :json, content: :all)

      assert filename == "workshop_#{session.code}_all.json"
      assert content_type == "application/json"

      decoded = Jason.decode!(data)
      assert Map.has_key?(decoded, "session")
      assert Map.has_key?(decoded, "questions")
      assert Map.has_key?(decoded, "actions")
    end

    test "handles empty notes gracefully", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, _participant} = Sessions.join_session(session, "Charlie", Ecto.UUID.generate())

      {:ok, {_filename, _content_type, data}} =
        Export.export(session, format: :csv, content: :results)

      assert data =~ "No notes recorded"
    end

    test "handles empty actions gracefully", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, _participant} = Sessions.join_session(session, "Charlie", Ecto.UUID.generate())

      {:ok, {_filename, _content_type, data}} =
        Export.export(session, format: :csv, content: :actions)

      assert data =~ "No action items recorded"
    end

    test "escapes CSV special characters", %{session: session} do
      {:ok, _participant} = Sessions.join_session(session, "Test, User", Ecto.UUID.generate())

      {:ok, _note} =
        Notes.create_note(session, 0, %{
          content: "Note with \"quotes\" and, commas",
          author_name: "Test, User"
        })

      {:ok, {_filename, _content_type, data}} =
        Export.export(session, format: :csv, content: :results)

      # CSV escaping should wrap in quotes and escape internal quotes
      assert data =~ "\"Test, User\""
      assert data =~ "\"Note with \"\"quotes\"\" and, commas\""
    end

    test "formats balance scores with + prefix for positive values", %{session: session} do
      {:ok, {_filename, _content_type, data}} =
        Export.export(session, format: :csv, content: :results)

      # Alice scored +1 on Elbow Room (balance scale)
      assert data =~ "+1"
    end
  end
end
