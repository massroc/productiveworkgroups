defmodule ProductiveWorkgroups.NotesTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Notes
  alias ProductiveWorkgroups.Notes.{Action, Note}
  alias ProductiveWorkgroups.{Sessions, Workshops}

  describe "notes" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Notes Test Workshop",
          slug: "test-notes",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session}
    end

    test "create_note/3 creates a question note", %{session: session} do
      assert {:ok, %Note{} = note} =
               Notes.create_note(session, 0, %{
                 content: "Important discussion point",
                 author_name: "Alice"
               })

      assert note.content == "Important discussion point"
      assert note.author_name == "Alice"
      assert note.question_index == 0
      assert note.session_id == session.id
    end

    test "create_note/3 creates a general session note", %{session: session} do
      assert {:ok, %Note{} = note} =
               Notes.create_note(session, nil, %{
                 content: "General session observation",
                 author_name: "Bob"
               })

      assert note.question_index == nil
    end

    test "create_note/3 requires content", %{session: session} do
      assert {:error, changeset} = Notes.create_note(session, 0, %{author_name: "Alice"})
      assert "can't be blank" in errors_on(changeset).content
    end

    test "list_notes_for_question/2 returns notes for a specific question", %{session: session} do
      {:ok, _n1} = Notes.create_note(session, 0, %{content: "Note for Q1", author_name: "Alice"})

      {:ok, _n2} =
        Notes.create_note(session, 0, %{content: "Another note for Q1", author_name: "Bob"})

      {:ok, _n3} = Notes.create_note(session, 1, %{content: "Note for Q2", author_name: "Carol"})

      notes = Notes.list_notes_for_question(session, 0)
      assert length(notes) == 2
      assert Enum.all?(notes, fn n -> n.question_index == 0 end)
    end

    test "list_general_notes/1 returns session-wide notes", %{session: session} do
      {:ok, _n1} = Notes.create_note(session, nil, %{content: "General note 1"})
      {:ok, _n2} = Notes.create_note(session, nil, %{content: "General note 2"})
      {:ok, _n3} = Notes.create_note(session, 0, %{content: "Question note"})

      notes = Notes.list_general_notes(session)
      assert length(notes) == 2
      assert Enum.all?(notes, fn n -> n.question_index == nil end)
    end

    test "list_all_notes/1 returns all session notes", %{session: session} do
      {:ok, _} = Notes.create_note(session, nil, %{content: "General"})
      {:ok, _} = Notes.create_note(session, 0, %{content: "Q1"})
      {:ok, _} = Notes.create_note(session, 1, %{content: "Q2"})

      notes = Notes.list_all_notes(session)
      assert length(notes) == 3
    end

    test "update_note/2 updates content", %{session: session} do
      {:ok, note} = Notes.create_note(session, 0, %{content: "Original", author_name: "Alice"})

      {:ok, updated} = Notes.update_note(note, %{content: "Updated content"})
      assert updated.content == "Updated content"
    end

    test "delete_note/1 removes the note", %{session: session} do
      {:ok, note} = Notes.create_note(session, 0, %{content: "To delete"})

      assert {:ok, _} = Notes.delete_note(note)
      assert Notes.list_notes_for_question(session, 0) == []
    end

    test "count_notes/1 returns total note count", %{session: session} do
      assert Notes.count_notes(session) == 0

      {:ok, _} = Notes.create_note(session, 0, %{content: "Note 1"})
      {:ok, _} = Notes.create_note(session, 1, %{content: "Note 2"})

      assert Notes.count_notes(session) == 2
    end
  end

  describe "actions" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Actions Test Workshop",
          slug: "test-actions",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session}
    end

    test "create_action/2 creates a session action", %{session: session} do
      assert {:ok, %Action{} = action} =
               Notes.create_action(session, %{
                 description: "Follow up on elbow room concerns",
                 owner_name: "Alice"
               })

      assert action.description == "Follow up on elbow room concerns"
      assert action.owner_name == "Alice"
      assert action.completed == false
      assert action.session_id == session.id
    end

    test "create_action/2 creates action without owner", %{session: session} do
      assert {:ok, %Action{} = action} =
               Notes.create_action(session, %{
                 description: "Schedule follow-up meeting"
               })

      assert action.owner_name == nil
    end

    test "create_action/2 requires description", %{session: session} do
      assert {:error, changeset} = Notes.create_action(session, %{owner_name: "Alice"})
      assert "can't be blank" in errors_on(changeset).description
    end

    test "list_all_actions/1 returns all session actions in order", %{session: session} do
      {:ok, _} = Notes.create_action(session, %{description: "First"})
      {:ok, _} = Notes.create_action(session, %{description: "Second"})
      {:ok, _} = Notes.create_action(session, %{description: "Third"})

      actions = Notes.list_all_actions(session)
      assert length(actions) == 3
      assert Enum.map(actions, & &1.description) == ["First", "Second", "Third"]
    end

    test "update_action/2 updates description and owner", %{session: session} do
      {:ok, action} = Notes.create_action(session, %{description: "Original"})

      {:ok, updated} =
        Notes.update_action(action, %{description: "Updated", owner_name: "Bob"})

      assert updated.description == "Updated"
      assert updated.owner_name == "Bob"
    end

    test "complete_action/1 marks action as completed", %{session: session} do
      {:ok, action} = Notes.create_action(session, %{description: "To complete"})
      assert action.completed == false

      {:ok, completed} = Notes.complete_action(action)
      assert completed.completed == true
    end

    test "uncomplete_action/1 marks action as not completed", %{session: session} do
      {:ok, action} = Notes.create_action(session, %{description: "To toggle"})
      {:ok, action} = Notes.complete_action(action)
      assert action.completed == true

      {:ok, uncompleted} = Notes.uncomplete_action(action)
      assert uncompleted.completed == false
    end

    test "delete_action/1 removes the action", %{session: session} do
      {:ok, action} = Notes.create_action(session, %{description: "To delete"})

      assert {:ok, _} = Notes.delete_action(action)
      assert Notes.list_all_actions(session) == []
    end

    test "count_actions/1 returns total action count", %{session: session} do
      assert Notes.count_actions(session) == 0

      {:ok, _} = Notes.create_action(session, %{description: "Action 1"})
      {:ok, _} = Notes.create_action(session, %{description: "Action 2"})

      assert Notes.count_actions(session) == 2
    end

    test "count_completed_actions/1 returns completed action count", %{session: session} do
      {:ok, a1} = Notes.create_action(session, %{description: "Action 1"})
      {:ok, _a2} = Notes.create_action(session, %{description: "Action 2"})

      assert Notes.count_completed_actions(session) == 0

      {:ok, _} = Notes.complete_action(a1)
      assert Notes.count_completed_actions(session) == 1
    end
  end
end
