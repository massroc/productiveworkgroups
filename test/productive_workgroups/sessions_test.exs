defmodule ProductiveWorkgroups.SessionsTest do
  use ProductiveWorkgroups.DataCase, async: true

  alias ProductiveWorkgroups.Sessions
  alias ProductiveWorkgroups.Sessions.{Participant, Session}
  alias ProductiveWorkgroups.Workshops

  describe "sessions" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Test Workshop",
          slug: "test-workshop",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      %{template: template}
    end

    test "create_session/1 creates a session with generated code", %{template: template} do
      assert {:ok, %Session{} = session} = Sessions.create_session(template)
      assert session.code != nil
      assert String.length(session.code) >= 6
      assert session.state == "lobby"
      assert session.current_question_index == 0
      assert session.template_id == template.id
    end

    test "create_session/1 generates unique codes", %{template: template} do
      {:ok, session1} = Sessions.create_session(template)
      {:ok, session2} = Sessions.create_session(template)
      assert session1.code != session2.code
    end

    test "create_session/2 with custom settings", %{template: template} do
      settings = %{"skip_intro" => true, "timer_enabled" => false}

      assert {:ok, %Session{} = session} =
               Sessions.create_session(template, %{
                 planned_duration_minutes: 120,
                 settings: settings
               })

      assert session.planned_duration_minutes == 120
      assert session.settings == settings
    end

    test "get_session!/1 returns the session", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      assert Sessions.get_session!(session.id).id == session.id
    end

    test "get_session_by_code/1 returns the session", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      assert Sessions.get_session_by_code(session.code).id == session.id
    end

    test "get_session_by_code/1 returns nil for non-existent code" do
      assert Sessions.get_session_by_code("NONEXIST") == nil
    end

    test "get_session_by_code/1 is case-insensitive", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      assert Sessions.get_session_by_code(String.downcase(session.code)).id == session.id
      assert Sessions.get_session_by_code(String.upcase(session.code)).id == session.id
    end

    test "start_session/1 transitions from lobby to intro", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      assert session.state == "lobby"

      {:ok, updated} = Sessions.start_session(session)
      assert updated.state == "intro"
      assert updated.started_at != nil
    end

    test "advance_to_scoring/1 transitions from intro to scoring", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)

      {:ok, updated} = Sessions.advance_to_scoring(session)
      assert updated.state == "scoring"
      assert updated.current_question_index == 0
    end

    test "advance_question/1 increments question index", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)

      {:ok, updated} = Sessions.advance_question(session)
      assert updated.current_question_index == 1
    end

    test "advance_to_summary/1 transitions to summary", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)

      {:ok, updated} = Sessions.advance_to_summary(session)
      assert updated.state == "summary"
    end

    test "advance_to_actions/1 transitions to actions", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)

      {:ok, updated} = Sessions.advance_to_actions(session)
      assert updated.state == "actions"
    end

    test "complete_session/1 transitions to completed", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)
      {:ok, session} = Sessions.advance_to_actions(session)

      {:ok, updated} = Sessions.complete_session(session)
      assert updated.state == "completed"
      assert updated.completed_at != nil
    end

    test "touch_session/1 updates last_activity_at", %{template: template} do
      {:ok, session} = Sessions.create_session(template)

      # Set an older timestamp manually to test the update
      past_time = DateTime.add(DateTime.utc_now(), -60, :second) |> DateTime.truncate(:second)

      {:ok, session} =
        session
        |> Ecto.Changeset.change(last_activity_at: past_time)
        |> Repo.update()

      {:ok, updated} = Sessions.touch_session(session)
      assert DateTime.compare(updated.last_activity_at, past_time) == :gt
    end

    test "go_back_question/1 decrements question index", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_question(session)
      assert session.current_question_index == 1

      {:ok, updated} = Sessions.go_back_question(session)
      assert updated.current_question_index == 0
    end

    test "go_back_question/1 returns error at first question", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      assert session.current_question_index == 0

      assert {:error, :at_first_question} = Sessions.go_back_question(session)
    end

    test "go_back_to_intro/1 transitions from scoring Q0 to intro", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      assert session.state == "scoring"
      assert session.current_question_index == 0

      {:ok, updated} = Sessions.go_back_to_intro(session)
      assert updated.state == "intro"
      assert updated.current_question_index == 0
    end

    test "go_back_to_scoring/2 transitions from summary to last question", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)
      assert session.state == "summary"

      {:ok, updated} = Sessions.go_back_to_scoring(session, 7)
      assert updated.state == "scoring"
      assert updated.current_question_index == 7
    end

    test "go_back_to_summary/1 transitions from actions to summary", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, session} = Sessions.start_session(session)
      {:ok, session} = Sessions.advance_to_scoring(session)
      {:ok, session} = Sessions.advance_to_summary(session)
      {:ok, session} = Sessions.advance_to_actions(session)
      assert session.state == "actions"

      {:ok, updated} = Sessions.go_back_to_summary(session)
      assert updated.state == "summary"
    end

    test "get_session_with_participants/1 preloads participants", %{template: template} do
      {:ok, session} = Sessions.create_session(template)
      {:ok, _participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      result = Sessions.get_session_with_participants(session.id)
      assert length(result.participants) == 1
      assert hd(result.participants).name == "Alice"
    end
  end

  describe "participants" do
    setup do
      {:ok, template} =
        Workshops.create_template(%{
          name: "Test Workshop",
          slug: "test-participant-workshop",
          version: "1.0.0",
          default_duration_minutes: 180
        })

      {:ok, session} = Sessions.create_session(template)
      %{session: session}
    end

    test "join_session/3 creates a participant", %{session: session} do
      browser_token = Ecto.UUID.generate()

      assert {:ok, %Participant{} = participant} =
               Sessions.join_session(session, "Alice", browser_token)

      assert participant.name == "Alice"
      assert participant.browser_token == browser_token
      assert participant.status == "active"
      assert participant.is_ready == false
      assert participant.session_id == session.id
    end

    test "join_session/3 reuses existing participant with same browser_token", %{session: session} do
      browser_token = Ecto.UUID.generate()

      {:ok, p1} = Sessions.join_session(session, "Alice", browser_token)
      {:ok, p2} = Sessions.join_session(session, "Alice Updated", browser_token)

      assert p1.id == p2.id
      assert p2.name == "Alice Updated"
    end

    test "join_session/3 allows different participants with different tokens", %{session: session} do
      {:ok, p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      assert p1.id != p2.id
    end

    test "get_participant/2 finds participant by browser_token", %{session: session} do
      browser_token = Ecto.UUID.generate()
      {:ok, participant} = Sessions.join_session(session, "Alice", browser_token)

      assert Sessions.get_participant(session, browser_token).id == participant.id
    end

    test "get_participant/2 returns nil for non-existent token", %{session: session} do
      assert Sessions.get_participant(session, Ecto.UUID.generate()) == nil
    end

    test "list_participants/1 returns all participants", %{session: session} do
      {:ok, _p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, _p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      participants = Sessions.list_participants(session)
      assert length(participants) == 2
    end

    test "list_active_participants/1 returns only active participants", %{session: session} do
      {:ok, p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, _p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      {:ok, _} = Sessions.update_participant_status(p1, "inactive")

      active = Sessions.list_active_participants(session)
      assert length(active) == 1
      assert hd(active).name == "Bob"
    end

    test "update_participant_status/2 changes status", %{session: session} do
      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())

      {:ok, updated} = Sessions.update_participant_status(participant, "inactive")
      assert updated.status == "inactive"
    end

    test "set_participant_ready/2 sets ready state", %{session: session} do
      {:ok, participant} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      assert participant.is_ready == false

      {:ok, updated} = Sessions.set_participant_ready(participant, true)
      assert updated.is_ready == true
    end

    test "reset_all_ready/1 resets all participants' ready state", %{session: session} do
      {:ok, p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      {:ok, _} = Sessions.set_participant_ready(p1, true)
      {:ok, _} = Sessions.set_participant_ready(p2, true)

      :ok = Sessions.reset_all_ready(session)

      participants = Sessions.list_participants(session)
      assert Enum.all?(participants, fn p -> p.is_ready == false end)
    end

    test "all_participants_ready?/1 checks if all active participants are ready", %{
      session: session
    } do
      {:ok, p1} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, p2} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      refute Sessions.all_participants_ready?(session)

      {:ok, _} = Sessions.set_participant_ready(p1, true)
      refute Sessions.all_participants_ready?(session)

      {:ok, _} = Sessions.set_participant_ready(p2, true)
      assert Sessions.all_participants_ready?(session)
    end

    test "count_participants/1 returns participant count", %{session: session} do
      assert Sessions.count_participants(session) == 0

      {:ok, _} = Sessions.join_session(session, "Alice", Ecto.UUID.generate())
      {:ok, _} = Sessions.join_session(session, "Bob", Ecto.UUID.generate())

      assert Sessions.count_participants(session) == 2
    end
  end

  describe "session code generation" do
    test "generate_code/0 creates alphanumeric codes" do
      code = Sessions.generate_code()
      assert String.length(code) >= 6
      assert code =~ ~r/^[A-Z0-9]+$/
    end

    test "generate_code/0 creates unique codes" do
      codes = for _ <- 1..100, do: Sessions.generate_code()
      unique_codes = Enum.uniq(codes)
      assert length(unique_codes) == 100
    end
  end
end
